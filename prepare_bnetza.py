import pandas as pd

inp = "bnetza_data.csv"
out = "bnetza_min.csv"

# Dosya ; ile ayrılmış ve Almanca özel karakterler var.
# encoding için utf-8 dene, olmazsa latin1 fallback.
try:
    df = pd.read_csv(inp, sep=";", dtype=str, encoding="utf-8")
except UnicodeDecodeError:
    df = pd.read_csv(inp, sep=";", dtype=str, encoding="latin1")

keep = [
    "Ladeeinrichtungs-ID",
    "Betreiber",
    "Art der Ladeeinrichtung",
    "Anzahl Ladepunkte",
    "Nennleistung Ladeeinrichtung [kW]",
    "Straße",
    "Hausnummer",
    "Postleitzahl",
    "Ort",
    "Bundesland",
    "Breitengrad",
    "Längengrad",
]

missing = [c for c in keep if c not in df.columns]
if missing:
    raise SystemExit(f"Eksik kolon(lar): {missing}\nMevcut kolonlar: {list(df.columns)[:30]} ...")

df = df[keep].copy()

# Virgüllü ondalıkları noktaya çevir (koordinat ve kW alanları)
for col in ["Breitengrad", "Längengrad", "Nennleistung Ladeeinrichtung [kW]"]:
    df[col] = df[col].astype(str).str.replace(",", ".", regex=False)

# boş satırları at (lat/lon yoksa)
df = df[df["Breitengrad"].notna() & df["Längengrad"].notna()]
df = df[df["Breitengrad"].str.strip() != ""]
df = df[df["Längengrad"].str.strip() != ""]

df.to_csv(out, index=False)
print(f"OK -> {out}  rows={len(df)}")
