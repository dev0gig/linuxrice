/*
 * tasten-led -- schaltet die beiden LEDs in der F-Reihe des HP ENVY x360.
 *
 *     tasten-led mikro|ton  an|aus
 *
 * Aufgerufen wird das nicht direkt, sondern ueber ~/.local/bin/mikro-led und
 * ~/.local/bin/ton-led, die den Mute-Zustand aus PipeWire dazulesen.
 *
 * Warum es dieses Programm ueberhaupt gibt
 * ----------------------------------------
 * Beide LEDs haengen am Audio-Codec Realtek ALC245, Subsystem 0x103c8824.
 * Kernel 6.18 kennt fuer diese Subsystem-ID keinen Mute-LED-Quirk in
 * patch_realtek.c. Deshalb gibt es weder Eintraege unter /sys/class/leds/ noch
 * ALSA-Controls -- ohne dieses Programm bleiben beide dunkel.
 *
 * Am 20.08.2026 durch Ausprobieren ermittelt, und die beiden LEDs haengen
 * ueberraschenderweise an voellig verschiedenen Mechanismen:
 *
 *   F8 (Mikrofon stumm)  GPIO-Pin 2 des Codecs, Bit 0x04, AKTIV-LOW
 *                        low = LED an, high = LED aus.
 *                        Pin 0 und Pin 1 tun nachweislich nichts -- auch
 *                        nicht fuer die F5-LED, in beiden Richtungen geprueft.
 *
 *   F5 (Ton stumm)       COEF-Register 0x0b im Vendor-Widget 0x20,
 *                        Bits 2 und 3: 1<<3 = an, 1<<2 = aus.
 *                        Genau das Muster, das alc245_fixup_hp_mute_led_coefbit
 *                        im Kernel fuer verwandte HP-Geraete schreibt; der
 *                        Ruhewert 0x7774 traegt bereits das "aus"-Bit.
 *
 * Der Ton bleibt in allen Stellungen unbeeintraechtigt (geprueft).
 *
 * Warum C und warum eine Capability
 * ---------------------------------
 * Geschrieben wird ueber die hwdep-Schnittstelle des Codecs (/dev/snd/hwC0D0).
 * Der Kernel verlangt zum Oeffnen dieses Geraets CAP_SYS_RAWIO
 * (hda_hwdep_open in sound/pci/hda/hda_hwdep.c) -- Mitgliedschaft in der
 * Gruppe audio genuegt NICHT, und ein Skript kann keine Capability tragen.
 * Darum dieses kleine Binaerprogramm, installiert mit:
 *
 *     setcap cap_sys_rawio+ep /usr/local/bin/tasten-led
 *     chown root:audio ... && chmod 750 ...
 *
 * Es nimmt bewusst KEINE freien Verbs entgegen: Pin, Register und Bits stehen
 * fest, die Argumente waehlen nur LED und Zustand. Sonst waere es ein
 * Freifahrtschein, beliebige Register des Codecs zu beschreiben.
 *
 * Beim GPIO werden Maske und Richtung bei jedem Aufruf mitgeschickt, nicht nur
 * die Daten: nach einem Suspend oder einem Reset des Codecs stehen beide
 * wieder auf 0, ein blosses Datenschreiben liefe dann ins Leere. Das
 * COEF-Register wird aus demselben Grund gelesen, geaendert und
 * zurueckgeschrieben -- nur die zwei Bits, alles andere bleibt stehen.
 */

#include <fcntl.h>
#include <glob.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

/* aus include/uapi/sound/hda_hwdep.h -- der Header ist auf Void nicht
   installiert, die Struktur ist aber Teil der stabilen Kernel-ABI. */
struct hda_verb_ioctl {
	uint32_t verb;	/* nid << 24 | verb << 8 | param */
	uint32_t res;	/* Antwort des Codecs */
};
#define HDA_IOCTL_VERB_WRITE _IOWR('H', 0x11, struct hda_verb_ioctl)

#define NID_ROOT	0x00
#define NID_AFG		0x01	/* Audio Function Group, dort sitzen die GPIOs */
#define NID_VENDOR	0x20	/* Realtek-Vendor-Widget, dort sitzen die COEFs */

#define VERB_GET_PARAM		0xf00
#define PARAM_VENDOR_ID		0x00
#define VERB_SET_GPIO_DATA	0x715
#define VERB_SET_GPIO_MASK	0x716
#define VERB_SET_GPIO_DIR	0x717
/* Verbs mit 16-Bit-Nutzlast: die Verb-Nummer liegt in Bit 16..19, die
   Nutzlast in Bit 0..15 -- dieselbe Formel oben passt trotzdem. */
#define VERB_SET_PROC_COEF	0x400
#define VERB_SET_COEF_INDEX	0x500
#define VERB_GET_PROC_COEF	0xc00

#define CODEC_ID	0x10ec0245u	/* Realtek ALC245 */

#define MIKRO_PIN	0x04		/* GPIO-Bit 2 */
#define MIKRO_AN	0x00		/* aktiv-low: low leuchtet */
#define MIKRO_AUS	MIKRO_PIN

#define TON_COEF_IDX	0x0b
#define TON_MASKE	(3 << 2)
#define TON_AN		(1 << 3)
#define TON_AUS		(1 << 2)

static int sende(int fd, unsigned nid, unsigned verb, unsigned param, uint32_t *res)
{
	struct hda_verb_ioctl v;
	v.verb = (nid << 24) | (verb << 8) | param;
	v.res = 0;
	if (ioctl(fd, HDA_IOCTL_VERB_WRITE, &v) < 0)
		return -1;
	if (res)
		*res = v.res;
	return 0;
}

/* Das hwdep-Geraet des ALC245 suchen -- die Nummer kann sich verschieben,
   und hwC0D2 ist der HDMI-Codec. */
static int codec_oeffnen(void)
{
	glob_t g;
	int fd = -1;

	if (glob("/dev/snd/hwC*D*", 0, NULL, &g) != 0)
		return -1;
	for (size_t i = 0; i < g.gl_pathc; i++) {
		uint32_t id = 0;
		int f = open(g.gl_pathv[i], O_RDWR);
		if (f < 0)
			continue;
		if (sende(f, NID_ROOT, VERB_GET_PARAM, PARAM_VENDOR_ID, &id) == 0 &&
		    id == CODEC_ID) {
			fd = f;
			break;
		}
		close(f);
	}
	globfree(&g);
	return fd;
}

static int mikro_setzen(int fd, int an)
{
	return sende(fd, NID_AFG, VERB_SET_GPIO_MASK, MIKRO_PIN, NULL) ||
	       sende(fd, NID_AFG, VERB_SET_GPIO_DIR, MIKRO_PIN, NULL) ||
	       sende(fd, NID_AFG, VERB_SET_GPIO_DATA, an ? MIKRO_AN : MIKRO_AUS, NULL);
}

static int ton_setzen(int fd, int an)
{
	uint32_t wert = 0;

	if (sende(fd, NID_VENDOR, VERB_SET_COEF_INDEX, TON_COEF_IDX, NULL) ||
	    sende(fd, NID_VENDOR, VERB_GET_PROC_COEF, 0, &wert))
		return -1;
	wert = (wert & ~(uint32_t)TON_MASKE) | (an ? TON_AN : TON_AUS);
	return sende(fd, NID_VENDOR, VERB_SET_COEF_INDEX, TON_COEF_IDX, NULL) ||
	       sende(fd, NID_VENDOR, VERB_SET_PROC_COEF, wert & 0xffff, NULL);
}

int main(int argc, char **argv)
{
	int an, fd, fehler;

	if (argc != 3 ||
	    (strcmp(argv[1], "mikro") && strcmp(argv[1], "ton")) ||
	    (strcmp(argv[2], "an") && strcmp(argv[2], "aus"))) {
		fprintf(stderr, "Aufruf: %s mikro|ton an|aus\n", argv[0]);
		return 2;
	}
	an = strcmp(argv[2], "an") == 0;

	fd = codec_oeffnen();
	if (fd < 0) {
		fprintf(stderr, "tasten-led: kein ALC245 gefunden oder keine "
				"Berechtigung (CAP_SYS_RAWIO noetig)\n");
		return 1;
	}
	fehler = strcmp(argv[1], "mikro") == 0 ? mikro_setzen(fd, an) : ton_setzen(fd, an);
	close(fd);
	if (fehler) {
		perror("tasten-led: Schreiben fehlgeschlagen");
		return 1;
	}
	return 0;
}
