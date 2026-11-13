# Ehrliche Antworten fuer Roblox' Maturity-&-Compliance-Fragebogen (IARC), pro Spiel.
# Aufruf: python3 answers.py <universeId> <format>  -> JSON {"answers": [...]} auf stdout
# format: "str" (Radio = Options-ID, Checkbox = JSON-Liste als Text), "list" (immer Liste), "csv"
import json, sys

# Spielinhalte (aus dem Code geprueft, 2026-11-13)
GAMES = {
    # name, Gewalt gegen Menschen/Avatare, Gewalt gegen Nicht-Menschen, Setting, oft gezeigt, unschuldige Opfer,
    # duester/bedrohlich, Grusel, bezahlte Zufallsitems, realistisch beschriebene Verbrechen
    "3003317051":  dict(name="Steal a Animal", hum=True,  non=False, real=False, often=False, innocent=False, dark=False, fear=False, rnd=True,  crime=False),  # Slap stunt Spieler
    "10772779320": dict(name="Turbo City",     hum=True,  non=False, real=True,  often=True,  innocent=False, dark=False, fear=False, rnd=False, crime=True),   # Cops & Robbers, Blaster
    "10772779368": dict(name="Colosseum",      hum=False, non=True,  real=False, often=True,  innocent=False, dark=False, fear=False, rnd=False, crime=False),  # Kreaturen-Kaempfe
    "10772779494": dict(name="Fire Blaster Race", hum=True, non=False, real=False, often=True, innocent=False, dark=False, fear=False, rnd=False, crime=False), # Blaster auf Karts
    "10772818148": dict(name="Lantern Legends", hum=True, non=True,  real=False, often=True,  innocent=False, dark=True,  fear=True,  rnd=False, crime=False),  # Dungeon-Monster
    "10772779235": dict(name="Lanebreakers",   hum=True,  non=True,  real=False, often=True,  innocent=False, dark=False, fear=False, rnd=False, crime=False),  # MOBA
    "10772818139": dict(name="Midnight Mystery", hum=True, non=False, real=True, often=True,  innocent=True,  dark=True,  fear=True,  rnd=True,  crime=False),  # Murder Mystery, Kisten
    "10772778395": dict(name="Obby",           hum=False, non=False, real=False, often=False, innocent=False, dark=False, fear=False, rnd=False, crime=False),
    "10772778924": dict(name="Critter Hatch",  hum=False, non=False, real=False, often=False, innocent=False, dark=False, fear=False, rnd=True,  crime=False),  # Eier
    "10772779542": dict(name="Soccer Jam",     hum=True,  non=False, real=False, often=True,  innocent=False, dark=False, fear=False, rnd=True,  crime=False),  # K.o.-Tackles, Spin
    "10772779420": dict(name="Surf",           hum=True,  non=False, real=False, often=True,  innocent=False, dark=False, fear=False, rnd=True,  crime=False),  # Schneeball-Arena
    "10772779164": dict(name="Magic Garden Tycoon", hum=False, non=False, real=False, often=False, innocent=False, dark=False, fear=False, rnd=False, crime=False),
}

def build(g):
    A = {}  # questionId -> [optionIds]
    def a(q, *o): A[q] = list(o)
    a("5fb74487-3593-db35-6068-573f0fbf34fb", "11361461-f123-c9e8-8d25-59bf508a5b6e")  # Game
    # Gewalt
    if g["hum"] or g["non"]:
        a("c413624b-c41d-3cdc-ea3e-c529ae5a6bcc", "22927863-670e-ea55-f3e5-7d8f66c0f4c1")
        sel = []
        if g["hum"]:
            sel.append("45971196-11cf-e483-5014-e5a0a2c3431c")
            a("88bece89-3db9-c0f7-e524-b905a46b70c3", "42ba30da-183b-c625-e35f-56baef861fd3" if g["real"] else "d6b97c62-0b2c-6544-7487-d35d11a5bbd6")
            a("a3bf5c3d-2bd1-0b5b-9726-acf395af3053", "9817f085-b9d9-f9d0-5298-f89bd345c9a8")  # kindlicher Stil
            a("aae5aa94-2963-e93c-cc88-9781e6da05eb", "76e5aab8-cb9e-7311-2e87-5673cd92c920")  # unrealistische Reaktionen
            a("a319d672-3de5-acb8-986b-e0f1a57bfd83", "c234c77b-3564-a03a-4f3d-178a37c0e148" if g["often"] else "e9e3386f-d736-7afe-f3a3-7d6b7d892adf")
            a("53b22584-4ccf-6d13-be83-6b3bdfdf9aca", "ae1f3725-d193-4c75-2826-8a6056d2c8f7")  # kein Blut
            a("08fee0da-8dad-03b0-af48-3764fbce5302", "4319c671-c6a0-f062-1f5e-9a4ab78e7897")  # kein Kriegssetting
            a("5e7c7113-ccbe-b774-9ffd-c559b0afe0f3", "5403441a-e75f-df18-d414-033021092159" if g["innocent"] else "f7236bc5-75d8-6f5f-ef57-86ac4d097df2")
            a("014224b7-f50e-393d-e9d7-22be153a2fe3", "94c17f4a-2431-535a-80ac-00e46e3ee77c" if g["dark"] else "d56f56ce-d63d-eb95-8ead-bc6205f483a3")
        if g["non"]:
            sel.append("8225e2ba-2f31-0719-efb2-f4264ca245fe")
            a("9257e2ef-f44a-213d-1d7d-119e090ed92d", "83a1a387-224b-9d24-0069-6cbd0fb61736")  # fantastisch
            a("f7386372-c8ff-7650-3925-bddb19a7a03e", "1c41d407-615f-0f3d-65b6-cefbb6230be0")
            a("c7434b6d-f2be-6844-439e-8cb8ba507bbf", "5dbbcae6-47fb-dc5b-e532-887cc342cd88")
            a("cdb2db74-3900-d399-ee2d-6ba75c8ec87a", "1a2717a9-a22b-95e3-22f9-354d195fdaf9")  # oft, aus Distanz
            a("bf4fcf56-636b-0413-dc7c-39cfbaa98e77", "3aee1fd2-dc5e-73a7-5ba6-775031377819")  # kein Blut
            a("3690f47c-c187-0678-98d3-16bcd666e124", "8caf821d-fbd4-cf06-c931-ac60454c6926")
            a("ba2fed12-1336-f252-8cc9-eda6df500991", "40813b3e-b278-64e2-22b6-a16abd7d1e0f")
            a("b2061d00-77f9-3879-6a35-104674ed8e3b", "54b2d442-4c8e-1a8b-0b27-3b3ac2f7fce7" if g["dark"] else "aa1abe8b-2d9c-b638-83f6-a5fbb64715c2")
        a("7dc37967-b9a0-d349-8742-5f1d46f0eaeb", *sel)
    else:
        a("c413624b-c41d-3cdc-ea3e-c529ae5a6bcc", "1fd7d8a4-a6af-b407-1026-7b1ef3daf33a")
    # Angst
    if g["fear"]:
        a("aa855a65-b7f9-4dd8-1e81-45ff1ab9968c", "6cf93d58-7fcb-d8c3-6c62-996f8989cd3d")
        a("75410440-4c7d-4422-0081-5eeeabeabe4a", "9ede2b9d-d24e-8ba1-29c0-9268425bf313")
        a("bc0cff3f-83d2-c0c0-258d-328ec9c313e6", "2da2e3f4-69b2-5746-8280-9154d42fba68")  # selten
    else:
        a("aa855a65-b7f9-4dd8-1e81-45ff1ab9968c", "882d7435-b528-6724-666c-3d640dd65a80")
    a("55637ee3-9437-8599-bae4-db26bfacd578", "0573e041-5c01-2d34-b0f1-de2d340d8c51")  # keine Sexualitaet
    a("ff28295c-34ac-5c70-cfa9-8d0a65126423", "0f64b019-c012-6823-ee21-b57ffef9f734")  # kein Gluecksspiel
    a("50c3c7c9-f9c1-4224-891b-5e4ad1631b46", "6717ab40-a186-d8a1-4b2b-49bf3902ae2e")  # keine Schimpfwoerter
    a("1a0939e0-7e21-cd18-789e-18a53b0e9220", "fc042308-7a51-acbf-f110-bf741d9cd320")  # keine Drogen/Alkohol
    a("42d361f9-66f2-f36e-6b71-1fa9556a111a", "58590f76-3019-7f2f-ee59-097071c4ab18")  # kein Fäkalhumor
    # Kaeufe (alle Spiele haben Gamepasses/Developer Products)
    a("6e580d23-f201-e19d-2eef-bd443f7e14df", "bb86f11d-e434-9aaa-8734-d47223f2d2a4")
    a("50c3e784-16e8-a079-1a4f-3d2e286b8d6e", "88e9422a-b667-a77b-2497-eab5bc771f3d")
    a("9a4338a4-db80-65b5-ed64-322348cf0534", "cf94bc53-fab1-6b5c-9839-6b32a6c1f167" if g["rnd"] else "c7cd353b-f373-34c8-c532-8ba581f8b2f5")
    a("412256c6-df8a-f019-b7cd-2f9af82415fe", "d3fffcdc-5b1e-fde4-7e49-613cacea6f24")  # kein Echtgeld-Handel
    # Verschiedenes: Roblox-Chat mit Blockieren, Melden, Moderation
    a("f28bb90c-08dd-a347-cad9-87bb95fd7c0f", "e4100261-67ab-0c84-637a-9afd215d2ebb")
    a("47a2e57d-147c-61e4-421f-34008887f256", "9061c09b-6afe-0632-2bdb-25686dd3b909")
    a("c23759d7-d3dd-ad6c-4067-45823bd13b9e", "9ef89c6c-4a83-a6b8-46bc-c4aa7a9e43b6")
    a("9afe903c-737d-a1fd-ccce-e4d1b318614c", "41d4cb60-07c6-6f6d-2768-393a0e995c4c")
    a("d2e9f17b-40e2-d685-b82a-96120699f725", "a55481a5-34cb-7c62-15e3-77d68505cad8")
    a("e2fa128b-4ce1-2cd6-af4e-20829f15a30d", "ad3348e8-9db5-d141-3b85-75e484cbc81c")  # kein Standort
    a("b6b6bdaf-fc91-0c93-ebfe-2332f6b300c1", "c8cf9af7-919f-3bce-a0ba-bbaf3b509263")
    a("ed4b886b-671d-084a-b79a-45ce1e87cd22", "fbfb8d13-f4b5-9edb-916b-521d60479b54")
    a("bc4486d0-28be-c43a-72b0-4db2ee8ed6d9", "c83f20f3-86b4-6302-b9a0-6d010dff53fc")
    if g["crime"]:
        a("ad4b059d-f88b-be45-5754-2e69c10c13a8", "71a7f815-f6ac-3678-be0c-cff8c73ae867")
        a("bb2d96b0-5e9a-0dd3-540a-06a2b4bb7289", "a4d35517-d248-4cc7-22f3-d12e80faad1e")
        a("cf587185-8789-28d6-f810-92a6a64fe538", "bccdbb46-8a8a-d5fe-7d18-dd6134e4de8d")
    else:
        a("ad4b059d-f88b-be45-5754-2e69c10c13a8", "1d5de24f-4030-81a8-27ad-34ae10aa731d")
    return A

CHECKBOX = {"7dc37967-b9a0-d349-8742-5f1d46f0eaeb", "a319d672-3de5-acb8-986b-e0f1a57bfd83", "cdb2db74-3900-d399-ee2d-6ba75c8ec87a",
            "75410440-4c7d-4422-0081-5eeeabeabe4a", "50c3e784-16e8-a079-1a4f-3d2e286b8d6e"}

def fmt(A, f):
    out = []
    for q, opts in A.items():
        if f == "list": v = opts
        elif f == "csv": v = ",".join(opts)
        elif f == "str": v = json.dumps(opts) if q in CHECKBOX else opts[0]
        elif f == "each": v = opts[0] if len(opts) == 1 else opts
        elif f == "jsonarr": v = json.dumps(opts)
        elif f == "jsonstr": v = json.dumps(opts[0]) if len(opts) == 1 else json.dumps(opts)
        elif f == "final": v = json.dumps(opts) if q in CHECKBOX else json.dumps(opts[0])
        elif f == "semi": v = ";".join(opts)
        elif f == "pipe": v = "|".join(opts)
        out.append({"questionId": q, "value": v})
    return out

if __name__ == "__main__":
    u, f = sys.argv[1], sys.argv[2]
    print(json.dumps({"answers": fmt(build(GAMES[u]), f)}))
