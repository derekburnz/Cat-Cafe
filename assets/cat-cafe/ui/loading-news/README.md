# Loading screen WHAT'S NEW pictures (#5114)

Derek 2026-11-17: "for loading screen make it better images/models of how recent updates are shown".
One wordless picture per `LoadingNews` entry, 576x248 (twice the card's 288x124 picture box), 128-colour PNGs of
20 to 45 KB so a phone gets them fast. Made from the real renders (update posters, outfit pack cards, glossy cats).

| File | Entry | From |
|---|---|---|
| CatCafe_LoadingNews_worlds.png | worlds | 3 New Worlds poster, the three gate panels |
| CatCafe_LoadingNews_rift.png | rift | Comet (Mythic) in front of the rift's pink rings |
| CatCafe_LoadingNews_outfits.png | outfits | the four outfit pack cards' cat rows |
| CatCafe_LoadingNews_secret.png | secret | the dark shapes only (dark-shape rule in game) |
| CatCafe_LoadingNews_devices.png | (Better on Every Device, Nov 18) | its poster art |
| CatCafe_LoadingNews_harvest.png | (Harvest Hollow, Nov 25) | its poster art |

Rebuild: `UI=<repo>/assets/cat-cafe CUTS=<project files>/Model-Agent/home-thumbs-2026-11-17 OUT=<dir> python3 src/ln.py`.

Uploaded 2026-11-17 15:28 UTC (group owned): worlds 131886724226249, rift 87565789039061, outfits 118093955309484,
secret 75023525829478, devices 126122434701900, harvest 115151755242705. The devices and harvest ids go on their
LoadingNews entries when those cards are added.
