# Garak system prompt osszesites

Ez az osszesites a vegleges Garak futasokbol keszult.
A Garak meresekben a guardrail beallitas kontrollalt korulmeny, minden futas guardrail_defaultV2 profillal szerepel.
A fo osszehasonlitasi dimenzio a system prompt.

## Adatkor

- Futások száma: 32
- Modellek száma: 4
- System promptok száma: 4
- Teszttípusok száma: 2

## Atlagos tamadasi sikeresseg system prompt szerint

- system_baseline_minimal: ASR=0.561, Azure content filter rate=0.490
- system_security_hardened_chatbot: ASR=0.256, Azure content filter rate=0.488
- system_security_hardened_no_code: ASR=0.270, Azure content filter rate=0.496
- system_standard_chatbot_safety: ASR=0.359, Azure content filter rate=0.491

## Ertelmezesi szabalyok

- Az attack_success_rate_scored a fo Garak biztonsagi mutato.
- Az azure_content_filter_rate Azure vedelmi beavatkozasi mutato, nem modellvalasz-minosegi pontszam.
- A system_security_hardened_no_code prompt kiegeszito kiserletkent kezelendo.
- A compare tablaban a negativ absolute_delta javulast jelent a baseline prompttal szemben.

## Kimeneti fajlok

- run_summary.csv: egy sor egy Garak futas.
- system_prompt_comparison.csv: baseline-hoz viszonyitott prompt hatas.
- probe_summary.csv: probe szintu Garak detector bontas.

System prompt osszehasonlito sorok szama: 24
