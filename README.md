# Ubuntu 24.04 LTS CIS Hardening Toolkit

![Status](https://img.shields.io/badge/status-beta-blue)
![Licentie](https://img.shields.io/badge/licentie-MIT-blue)
![Benchmark](https://img.shields.io/badge/CIS%20Benchmark-Ubuntu%2024.04%20v1.0.0-green)
![Backend](https://img.shields.io/badge/backend-Ubuntu%20Security%20Guide%20(USG)-orange)

Een dunne Bash-wrapper rond **Ubuntu Security Guide (USG)** voor het hardenen en auditeren van Ubuntu 24.04 LTS Server op basis van de CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0.

> **Waarom een wrapper en niet zelf implementeren?**
> USG is Canonicals officiële tool voor CIS-compliance op Ubuntu. Het bevat honderden nauwkeurig geïmplementeerde en geteste controls. Zelf implementeren zou het wiel opnieuw uitvinden — foutgevoeliger, minder onderhoudbaar, en altijd achter op updates. Deze toolkit biedt een eenvoudige interface bovenop USG, plus ondersteuning voor organisatie-specifieke tailoring.

> ⚠️ **Disclaimer:** Hardening wijzigt diepgaand de systeemconfiguratie. Gebruik uitsluitend op verse installaties of in een testomgeving. Maak altijd een snapshot vóór uitvoering. De auteur is niet verantwoordelijk voor verlies van toegang of functionaliteit.

---

## Vereisten

| Vereiste | Details |
|---|---|
| OS | Ubuntu Server 24.04 LTS (Noble Numbat), x86_64 |
| Rechten | Root of sudo |
| Ubuntu Pro | Gratis tot 5 apparaten — [ubuntu.com/pro](https://ubuntu.com/pro) |
| USG | Wordt automatisch geïnstalleerd als Ubuntu Pro actief is |

### Ubuntu Pro activeren (eenmalig)

```bash
sudo pro attach <jouw-token>   # token ophalen op ubuntu.com/pro
sudo pro enable usg
sudo apt install usg
```

---

## Gebruik

### Hardening toepassen

```bash
git clone https://github.com/WildcatKSS/Ubuntu-24.04-LTS-CIS-Hardening-Toolkit.git
cd Ubuntu-24.04-LTS-CIS-Hardening-Toolkit
sudo ./harden.sh
```

Het script vraagt welk CIS-profiel je wilt toepassen:

```
Selecteer CIS-profiel:
  1) Level 1 Server  — aanbevolen baseline
  2) Level 2 Server  — strenger, mogelijk impact op functionaliteit
  q) Afsluiten
```

Na voltooiing: `sudo reboot`

### Compliance auditeren (zonder wijzigingen)

```bash
sudo ./audit.sh
```

Het HTML-rapport wordt opgeslagen in `/var/log/cis-audit/` en `/var/lib/usg/usg-report.html`.

---

## Profielen aanpassen (tailoring)

Standaard worden de profielen ongewijzigd toegepast. Voor omgeving-specifieke aanpassingen gebruik je tailoring-bestanden.

### Via de toolkit (aanbevolen)

```bash
sudo ./change-cis-profile.sh
```

Kies het profiel (L1 of L2). USG opent een browser-wizard waar je per CIS-control kunt kiezen of deze actief is. Na opslaan wordt het tailoring-bestand bewaard in `tailoring/` en automatisch geladen door `harden.sh` en `audit.sh`.

### Handmatig bewerken

Bewerk `tailoring/level1-server.xml` of `tailoring/level2-server.xml` direct.
Voeg `<xccdf-1.2:select>` elementen toe in het `Profile`-blok:

```xml
<!-- Control uitschakelen -->
<xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_sshd_set_loglevel_verbose" selected="false"/>
```

De tailoring-bestanden worden automatisch geladen als ze aanwezig zijn — geen configuratie nodig.

---

## Projectstructuur

```
.
├── harden.sh                  # Hardening via USG fix
├── audit.sh                   # Compliance-audit via USG audit
├── change-cis-profile.sh      # Profiel aanpassen via USG tailoring wizard
├── lib/
│   └── common.sh              # Gedeelde functies (logging, preflight, profielkeuze, USG setup)
└── tailoring/
    ├── level1-server.xml      # Optionele aanpassingen op L1 profiel
    └── level2-server.xml      # Optionele aanpassingen op L2 profiel
```

---

## Scope

| Item | Waarde |
|---|---|
| Doel-OS | Ubuntu Server 24.04 LTS |
| Architectuur | x86_64 |
| Benchmark | CIS Ubuntu Linux 24.04 LTS v1.0.0 |
| Profielen | Level 1 Server, Level 2 Server |
| Niet in scope | Workstation-profielen, container-images |

---

## Hoe USG controls uitvoert

USG leest de SCAP-benchmark bestanden in `/usr/share/ubuntu-scap-security-guides/current/benchmarks/` en past de controls toe via het onderliggende OpenSCAP-framework. Bij `usg fix` worden systeeminstellingen gewijzigd; bij `usg audit` wordt alleen gerapporteerd.

Controls zoeken:

```bash
# Welke rules zijn beschikbaar in een profiel?
usg audit cis_level1_server 2>&1 | grep "Rule"

# Benchmark bestanden bekijken
ls /usr/share/ubuntu-scap-security-guides/current/benchmarks/
```

---

## Credits & Referenties

- [Ubuntu Security Guide (USG)](https://ubuntu.com/security/certifications/docs/usg) — Canonical
- [CIS Ubuntu Linux 24.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux) — Center for Internet Security

---

## Licentie

MIT — zie `LICENSE`. CIS Benchmarks zijn eigendom van het Center for Internet Security; deze repository bevat geen benchmarkteksten.
