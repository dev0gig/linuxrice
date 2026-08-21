/*
 * sperrsaver -- zeigt das Sperrbild im Fenster von xsecurelock an.
 *
 *     sperrsaver <bild-finger.png> <bild-nochmal.png> <zustandsdatei>
 *
 * Aufgerufen wird es nicht direkt, sondern von
 * /usr/libexec/xsecurelock/saver_ehwaz -- dem Saver-Modul, das xsecurelock
 * startet. Die Bilder baut ~/.local/bin/sperrbild mit ImageMagick.
 *
 * Warum es dieses Programm ueberhaupt gibt
 * ----------------------------------------
 * xsecurelock zeichnet selbst nur eine Farbflaeche und uebergibt dem
 * Saver-Modul in $XSCREENSAVER_WINDOW ein Fenster zum Bemalen. Das
 * naheliegende "display -window $XSCREENSAVER_WINDOW bild.png" von
 * ImageMagick scheitert hier: display sucht das Fenster ueber den Namen im
 * Fensterbaum, und die Fenster von xsecurelock sind namenlos und
 * override-redirect. Es meldet dann "no window with specified ID exists",
 * obwohl es die Kennung gibt -- nachgemessen auf einem Xvfb-Testschirm.
 *
 * Statt eine schwere Abhaengigkeit wie mpv nur zum Anzeigen eines Standbilds
 * mitzuschleppen (so macht es saver_mpv), zeichnet dieses Programm das PNG
 * mit cairo direkt.
 *
 * Es malt bewusst NICHT in $XSCREENSAVER_WINDOW selbst, sondern legt ein
 * eigenes Kindfenster hinein. Das ist in der Anleitung von xsecurelock so
 * vorgesehen ("may draw on or create windows below") und hat einen
 * praktischen Grund: xsecurelock holt sein Fenster regelmaessig nach vorn und
 * fuellt es dabei neu mit der Hintergrundfarbe. Ein direkt hineingemaltes
 * Bild waere danach weg, ein eigenes Fenster bleibt.
 *
 * Der Zustand kommt aus einer Datei und nicht ueber ein Signal: so kann der
 * Fingerabdruck-Waechter ihn umlegen, ohne die Prozessnummer dieses
 * Programms zu kennen. Steht dort "nochmal", wird das zweite Bild gezeigt.
 */

#define _POSIX_C_SOURCE 200809L

#include <X11/Xlib.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/select.h>

/* Wie oft die Zustandsdatei nachgelesen wird. 200 ms sind fuer das Auge
 * sofort und kosten praktisch nichts. */
static const long PRUEFUNG_US = 200000;

static cairo_surface_t *lade(const char *pfad)
{
    cairo_surface_t *bild = cairo_image_surface_create_from_png(pfad);
    if (cairo_surface_status(bild) != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "sperrsaver: %s nicht lesbar: %s\n", pfad,
                cairo_status_to_string(cairo_surface_status(bild)));
        cairo_surface_destroy(bild);
        return NULL;
    }
    return bild;
}

/* Liest die Zustandsdatei. Alles ausser "nochmal" gilt als Ausgangszustand --
 * eine fehlende oder halb geschriebene Datei darf nie den Fehlertext
 * zeigen. */
static int ist_nochmal(const char *pfad)
{
    char puffer[32] = {0};
    FILE *f = fopen(pfad, "r");
    if (!f)
        return 0;
    size_t gelesen = fread(puffer, 1, sizeof puffer - 1, f);
    fclose(f);
    puffer[gelesen] = '\0';
    return strncmp(puffer, "nochmal", 7) == 0;
}

static void zeichne(cairo_surface_t *ziel, cairo_surface_t *bild,
                    int breite, int hoehe)
{
    cairo_t *cr = cairo_create(ziel);

    if (bild) {
        /* Die Bilder werden von sperrbild schon in Bildschirmgroesse gebaut.
         * Falls der Schirm sich seither geaendert hat, wird skaliert statt
         * einen schwarzen Rand zu lassen. */
        double bb = cairo_image_surface_get_width(bild);
        double bh = cairo_image_surface_get_height(bild);
        if (bb > 0 && bh > 0)
            cairo_scale(cr, breite / bb, hoehe / bh);
        cairo_set_source_surface(cr, bild, 0, 0);
        cairo_paint(cr);
    } else {
        /* Ohne Bild bleibt es dunkel -- niemals durchsichtig, sonst laege
         * der Schreibtisch offen. */
        cairo_set_source_rgb(cr, 0.086, 0.086, 0.086);   /* #161616 */
        cairo_paint(cr);
    }

    cairo_destroy(cr);
}

int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(stderr,
                "Aufruf: %s <bild-finger.png> <bild-nochmal.png> <zustandsdatei>\n",
                argv[0]);
        return 2;
    }

    const char *bild_finger  = argv[1];
    const char *bild_nochmal = argv[2];
    const char *zustandsdatei = argv[3];

    Display *anzeige = XOpenDisplay(NULL);
    if (!anzeige) {
        fprintf(stderr, "sperrsaver: kein X-Server erreichbar\n");
        return 1;
    }

    /* xsecurelock uebergibt die Fensterkennung dezimal. strtoul mit Basis 0
     * nimmt beides, auch eine hexadezimale Schreibweise. */
    const char *umgebung = getenv("XSCREENSAVER_WINDOW");
    Window eltern = umgebung ? (Window)strtoul(umgebung, NULL, 0) : 0;
    if (eltern == 0)
        eltern = DefaultRootWindow(anzeige);

    XWindowAttributes masse;
    if (!XGetWindowAttributes(anzeige, eltern, &masse)) {
        fprintf(stderr, "sperrsaver: Fenster %lu nicht lesbar\n",
                (unsigned long)eltern);
        return 1;
    }

    Window fenster = XCreateSimpleWindow(anzeige, eltern, 0, 0,
                                         masse.width, masse.height, 0, 0, 0);
    XSelectInput(anzeige, fenster, ExposureMask | StructureNotifyMask);
    XMapWindow(anzeige, fenster);

    cairo_surface_t *ziel = cairo_xlib_surface_create(anzeige, fenster,
                                                      masse.visual,
                                                      masse.width, masse.height);
    cairo_surface_t *bilder[2] = { lade(bild_finger), lade(bild_nochmal) };

    int zustand = -1;                 /* erzwingt das erste Zeichnen */
    int x_fd = ConnectionNumber(anzeige);

    for (;;) {
        int neuer = ist_nochmal(zustandsdatei);
        if (neuer != zustand) {
            zustand = neuer;
            zeichne(ziel, bilder[zustand], masse.width, masse.height);
            XFlush(anzeige);
        }

        /* Ereignisse abraeumen und bei Bedarf neu zeichnen. */
        while (XPending(anzeige)) {
            XEvent e;
            XNextEvent(anzeige, &e);
            if (e.type == Expose && e.xexpose.count == 0) {
                zeichne(ziel, bilder[zustand], masse.width, masse.height);
                XFlush(anzeige);
            } else if (e.type == ConfigureNotify) {
                masse.width = e.xconfigure.width;
                masse.height = e.xconfigure.height;
                cairo_xlib_surface_set_size(ziel, masse.width, masse.height);
                zeichne(ziel, bilder[zustand], masse.width, masse.height);
                XFlush(anzeige);
            }
        }

        /* Warten, bis entweder X etwas meldet oder die Zeit fuer die
         * naechste Pruefung der Zustandsdatei um ist. Ein blosses sleep
         * wuerde Expose-Ereignisse verschlafen und das Bild kurz leer
         * lassen. */
        fd_set lauschen;
        FD_ZERO(&lauschen);
        FD_SET(x_fd, &lauschen);
        struct timeval wartezeit = { .tv_sec = 0, .tv_usec = PRUEFUNG_US };
        select(x_fd + 1, &lauschen, NULL, NULL, &wartezeit);
    }

    /* nicht erreichbar: xsecurelock beendet den Saver mit SIGTERM */
}
