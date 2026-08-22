/*
 * sperrsaver -- zeigt das Sperrbild im Fenster von xsecurelock an.
 *
 *     sperrsaver <bild-finger.png> <bild-nochmal.png> <bild-aufwachen.png> \
 *                <zustandsdatei>
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
 * Programms zu kennen. Es gibt drei:
 *
 *   (leer)    -- Ausgangszustand, Fingerabdruck-Symbol
 *   nochmal   -- nach einem misslungenen Fingerversuch
 *   aufwachen -- der Rechner kommt gerade aus der Bereitschaft: statt des
 *                Symbols laeuft ein Ladekreis, bis der Fingerabdruckleser
 *                wieder antwortet.
 */

#define _POSIX_C_SOURCE 200809L

#include <X11/Xlib.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/select.h>

/* Wie oft die Zustandsdatei nachgelesen wird. 200 ms sind fuer das Auge
 * sofort und kosten praktisch nichts. */
static const long PRUEFUNG_US = 200000;

enum { Z_FINGER = 0, Z_NOCHMAL = 1, Z_AUFWACHEN = 2 };

/* ---- Ladekreis
 *
 * Die Masse sind Anteile der Bildschirmhoehe, genau wie in sperrbild -- so
 * sitzt der Kreis auf jedem Schirm an derselben Stelle wie sonst das
 * Fingerabdruck-Symbol. Dessen Oberkante liegt bei 27,8 % der Hoehe und die
 * Glyphe ist rund 12 % hoch (bei 1080 Zeilen: 300 und 131 Pixel, siehe die
 * Rechnung in sperrbild), ihre Mitte also bei 33,8 %.
 *
 * Der Kreis ist etwas kleiner als die Glyphe: er soll an ihrer Stelle
 * stehen, aber nicht groesser wirken als das, was er vertritt. */
static const double KREIS_MITTE_Y = 0.338;   /* Anteil der Hoehe */
static const double KREIS_RADIUS  = 0.045;
static const double KREIS_DICKE   = 0.0055;
static const double KREIS_BOGEN   = 1.7;     /* Radiant, knapp ein Viertel */
static const double KREIS_PERIODE = 1.2;     /* Sekunden je Umdrehung */
static const long   KREIS_US      = 40000;   /* 25 Bilder je Sekunde */

/* Nach so vielen Sekunden faellt die Anzeige von selbst auf das
 * Fingerabdruck-Bild zurueck. Zurueckgelegt wird der Zustand eigentlich vom
 * Waechter in ~/.local/bin/i3-sitzung, sobald der Leser antwortet -- aber
 * wenn gar kein Finger angelernt ist, laeuft dieser Waechter nicht, und ohne
 * die Schranke drehte sich der Kreis bis zum Entsperren weiter. */
static const int KREIS_HOECHSTDAUER = 30;

static const double PI = 3.14159265358979323846;

/* Farbe des Kreises: #e8e8e8, dieselbe wie der Text im Sperrbild. */
static const double HELL_R = 0.910, HELL_G = 0.910, HELL_B = 0.910;

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

/* Liest die Zustandsdatei. Alles Unbekannte gilt als Ausgangszustand -- eine
 * fehlende oder halb geschriebene Datei darf nie den Fehlertext zeigen. */
static int lies_zustand(const char *pfad)
{
    char puffer[32] = {0};
    FILE *f = fopen(pfad, "r");
    if (!f)
        return Z_FINGER;
    size_t gelesen = fread(puffer, 1, sizeof puffer - 1, f);
    fclose(f);
    puffer[gelesen] = '\0';
    if (strncmp(puffer, "nochmal", 7) == 0)
        return Z_NOCHMAL;
    if (strncmp(puffer, "aufwachen", 9) == 0)
        return Z_AUFWACHEN;
    return Z_FINGER;
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

/*
 * Zeichnet den Ladekreis -- und zwar nur sein Quadrat, nicht den ganzen
 * Schirm.
 *
 * Der Umweg ueber einen Zwischenpuffer hat zwei Gruende. Erstens muss der
 * Untergrund unter dem Kreis in jedem Bild neu her, sonst bliebe die Spur
 * der letzten Stellung stehen; das ganze Wallpaper 25-mal je Sekunde neu
 * aufzuziehen waere dafuer viel zu teuer. Zweitens braucht die weiche
 * Deckung des ruhenden Rings einen Untergrund, den cairo lesen kann -- auf
 * einer X11-Flaeche hiesse das, das Bild ueber das Netz zurueckzuholen.
 * Im Puffer liegt beides im Speicher.
 */
static void zeichne_kreis(cairo_surface_t *ziel, cairo_surface_t *bild,
                          int breite, int hoehe, double winkel)
{
    static cairo_surface_t *puffer = NULL;
    static int puffer_kante = 0;

    int radius = (int)(hoehe * KREIS_RADIUS + 0.5);
    int dicke  = (int)(hoehe * KREIS_DICKE + 0.5);
    if (radius < 4) radius = 4;
    if (dicke  < 2) dicke  = 2;

    int kante = 2 * (radius + dicke) + 4;
    int x0 = breite / 2 - kante / 2;
    int y0 = (int)(hoehe * KREIS_MITTE_Y + 0.5) - kante / 2;

    if (!puffer || puffer_kante != kante) {
        if (puffer)
            cairo_surface_destroy(puffer);
        puffer = cairo_image_surface_create(CAIRO_FORMAT_RGB24, kante, kante);
        puffer_kante = kante;
    }
    if (cairo_surface_status(puffer) != CAIRO_STATUS_SUCCESS)
        return;

    cairo_t *cr = cairo_create(puffer);

    /* Untergrund: derselbe Ausschnitt, der ohne Kreis dort laege. */
    cairo_translate(cr, -x0, -y0);
    if (bild) {
        double bb = cairo_image_surface_get_width(bild);
        double bh = cairo_image_surface_get_height(bild);
        cairo_save(cr);
        if (bb > 0 && bh > 0)
            cairo_scale(cr, breite / bb, hoehe / bh);
        cairo_set_source_surface(cr, bild, 0, 0);
        cairo_paint(cr);
        cairo_restore(cr);
    } else {
        cairo_set_source_rgb(cr, 0.086, 0.086, 0.086);
        cairo_paint(cr);
    }

    double mx = x0 + kante / 2.0;
    double my = y0 + kante / 2.0;
    cairo_set_line_width(cr, dicke);
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);

    /* Der ruhende Ring bleibt schwach stehen: er gibt dem laufenden Stueck
     * eine Bahn, sonst wirkt der Kreis wie ein irrender Strich. */
    cairo_set_source_rgba(cr, HELL_R, HELL_G, HELL_B, 0.20);
    cairo_arc(cr, mx, my, radius, 0, 2 * PI);
    cairo_stroke(cr);

    cairo_set_source_rgba(cr, HELL_R, HELL_G, HELL_B, 0.95);
    cairo_arc(cr, mx, my, radius, winkel, winkel + KREIS_BOGEN);
    cairo_stroke(cr);

    cairo_destroy(cr);

    cairo_t *cz = cairo_create(ziel);
    cairo_set_source_surface(cz, puffer, x0, y0);
    cairo_paint(cz);
    cairo_destroy(cz);
}

int main(int argc, char **argv)
{
    if (argc != 5) {
        fprintf(stderr,
                "Aufruf: %s <bild-finger.png> <bild-nochmal.png> "
                "<bild-aufwachen.png> <zustandsdatei>\n",
                argv[0]);
        return 2;
    }

    const char *zustandsdatei = argv[4];

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
    cairo_surface_t *bilder[3] = { lade(argv[1]), lade(argv[2]), lade(argv[3]) };

    int zustand = -1;                 /* erzwingt das erste Zeichnen */
    int x_fd = ConnectionNumber(anzeige);

    double winkel = 0;
    double schritt = 2 * PI * ((double)KREIS_US / 1000000.0) / KREIS_PERIODE;
    time_t beginn = 0;                /* seit wann steht "aufwachen" da */
    int abgelaufen = 0;

    for (;;) {
        int roh = lies_zustand(zustandsdatei);

        /* Notbremse, siehe KREIS_HOECHSTDAUER. Sie wird erst zurueckgenommen,
         * wenn der Zustand wirklich wechselt -- sonst begaenne die Messung
         * mit dem naechsten Durchlauf von vorn und der Kreis flackerte
         * zurueck. */
        if (roh != Z_AUFWACHEN) {
            beginn = 0;
            abgelaufen = 0;
        } else {
            if (beginn == 0)
                beginn = time(NULL);
            if (time(NULL) - beginn >= KREIS_HOECHSTDAUER)
                abgelaufen = 1;
        }
        int neuer = (roh == Z_AUFWACHEN && abgelaufen) ? Z_FINGER : roh;

        if (neuer != zustand) {
            zustand = neuer;
            winkel = 0;
            zeichne(ziel, bilder[zustand], masse.width, masse.height);
            if (zustand == Z_AUFWACHEN)
                zeichne_kreis(ziel, bilder[zustand],
                              masse.width, masse.height, winkel);
            XFlush(anzeige);
        } else if (zustand == Z_AUFWACHEN) {
            winkel += schritt;
            if (winkel >= 2 * PI)
                winkel -= 2 * PI;
            zeichne_kreis(ziel, bilder[zustand],
                          masse.width, masse.height, winkel);
            XFlush(anzeige);
        }

        /* Ereignisse abraeumen und bei Bedarf neu zeichnen. */
        while (XPending(anzeige)) {
            XEvent e;
            XNextEvent(anzeige, &e);
            if (e.type == Expose && e.xexpose.count == 0) {
                zeichne(ziel, bilder[zustand], masse.width, masse.height);
                if (zustand == Z_AUFWACHEN)
                    zeichne_kreis(ziel, bilder[zustand],
                                  masse.width, masse.height, winkel);
                XFlush(anzeige);
            } else if (e.type == ConfigureNotify) {
                masse.width = e.xconfigure.width;
                masse.height = e.xconfigure.height;
                cairo_xlib_surface_set_size(ziel, masse.width, masse.height);
                zeichne(ziel, bilder[zustand], masse.width, masse.height);
                if (zustand == Z_AUFWACHEN)
                    zeichne_kreis(ziel, bilder[zustand],
                                  masse.width, masse.height, winkel);
                XFlush(anzeige);
            }
        }

        /* Warten, bis entweder X etwas meldet oder die Zeit fuer das naechste
         * Bild um ist. Ein blosses sleep wuerde Expose-Ereignisse verschlafen
         * und das Bild kurz leer lassen. Waehrend der Kreis laeuft, ist der
         * Takt der der Animation, sonst der traege der Zustandspruefung. */
        fd_set lauschen;
        FD_ZERO(&lauschen);
        FD_SET(x_fd, &lauschen);
        struct timeval wartezeit = {
            .tv_sec = 0,
            .tv_usec = (zustand == Z_AUFWACHEN) ? KREIS_US : PRUEFUNG_US
        };
        select(x_fd + 1, &lauschen, NULL, NULL, &wartezeit);
    }

    /* nicht erreichbar: xsecurelock beendet den Saver mit SIGTERM */
}
