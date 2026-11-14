// Clean HUD symbols for the 2026-11-03 style mockup: bold white shapes with a thick dark outline, one per button.
const O = '#2a1a12';
const S = `stroke="${O}" stroke-width="4.5" stroke-linejoin="round" stroke-linecap="round" paint-order="stroke"`;
window.ICONS = {
  cats: `<path ${S} fill="#ffb04a" d="M8 48 Q6 30 15 22 L12 5 L27 14 Q32 13 37 14 L52 5 L49 22 Q58 30 56 48 Q54 60 32 60 Q10 60 8 48 Z"/>
    <path d="M17 19 L15 10 L23 15 Z M47 19 L49 10 L41 15 Z" fill="#ff9ec4"/>
    <path d="M28 16 L29 24 M32 15 V24 M36 16 L35 24" stroke="#d9741f" stroke-width="3" stroke-linecap="round"/>
    <ellipse cx="22" cy="36" rx="5" ry="6" fill="${O}"/><ellipse cx="42" cy="36" rx="5" ry="6" fill="${O}"/>
    <circle cx="23.6" cy="33.6" r="2" fill="#fff"/><circle cx="43.6" cy="33.6" r="2" fill="#fff"/>
    <circle cx="15" cy="45" r="4" fill="#ff8fb3" opacity=".7"/><circle cx="49" cy="45" r="4" fill="#ff8fb3" opacity=".7"/>
    <path d="M29.5 42 H34.5 L32 45 Z" fill="#ff6f9a" stroke="${O}" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M26 47 Q29 51 32 47 Q35 51 38 47" stroke="${O}" stroke-width="2.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`,
  index: `<path ${S} fill="#fff" d="M6 14 Q19 9 32 16 Q45 9 58 14 V52 Q45 47 32 54 Q19 47 6 52 Z"/>
    <path d="M32 17 V52" stroke="${O}" stroke-width="4" stroke-linecap="round"/>
    <path d="M13 22 Q19 20 25 23 M13 30 Q19 28 25 31 M39 23 Q45 20 51 22 M39 31 Q45 28 51 30" stroke="#9bd1ff" stroke-width="3.5" fill="none" stroke-linecap="round"/>`,
  quests: `<rect ${S} x="12" y="6" width="40" height="52" rx="8" fill="#fff"/>
    <path d="M20 22 L26 28 L36 16" stroke="#2fbf4a" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M20 40 H44 M20 48 H38" stroke="${O}" stroke-width="4" stroke-linecap="round"/>`,
  upgrades: `<path ${S} fill="#fff" d="M32 5 L57 31 H43 V58 H21 V31 H7 Z"/>`,
  decor: `<path ${S} fill="#ffa3c8" d="M9 16 Q9 10 15 10 H33 Q39 10 39 16 V36 H9 Z"/>
    <circle cx="18" cy="21" r="2.4" fill="#e8558f"/><circle cx="30" cy="21" r="2.4" fill="#e8558f"/>
    <rect ${S} x="9" y="32" width="30" height="11" rx="4" fill="#ffbcd7"/>
    <path ${S} fill="#ff7eb0" d="M2 30 Q2 24 7.5 24 Q13 24 13 30 V50 H2 Z"/>
    <path ${S} fill="#ff7eb0" d="M35 30 Q35 24 40.5 24 Q46 24 46 30 V50 H35 Z"/>
    <path ${S} fill="#ff7eb0" d="M13 42 H35 V50 H13 Z"/>
    <path d="M6 50 V56 M42 50 V56" stroke="${O}" stroke-width="5" stroke-linecap="round"/>
    <path ${S} fill="#e07b4a" stroke-width="3.5" d="M47 42 H62 L60 58 H49 Z"/>
    <path ${S} fill="#3ccf5a" stroke-width="3" d="M54.5 42 Q46 34 49 24 Q56 31 54.5 42 Z"/>
    <path ${S} fill="#3ccf5a" stroke-width="3" d="M54.5 42 Q61 33 61 24 Q53 28 54.5 42 Z"/>`,
  store: `<path ${S} fill="#b8692e" d="M9 26 L5 9 Q5 4 11 4 H53 Q59 4 59 9 L55 26 Z"/>
    <path d="M19 5 L21 25 M45 5 L43 25" stroke="#ffd23f" stroke-width="4"/>
    <path ${S} fill="#ffd23f" stroke-width="3.5" d="M6 32 Q8 18 20 19 Q26 11 34 16 Q42 11 48 19 Q58 19 58 32 Z"/>
    <circle cx="17" cy="25" r="4" fill="none" stroke="#e7a812" stroke-width="2.2"/><circle cx="46" cy="24" r="4" fill="none" stroke="#e7a812" stroke-width="2.2"/>
    <path d="M24 24 L29 15 L34 24 L29 28 Z" fill="#ff5d8f" stroke="${O}" stroke-width="2.4" stroke-linejoin="round"/>
    <path d="M34 22 L39 14 L44 22 L39 26 Z" fill="#5fd0ff" stroke="${O}" stroke-width="2.4" stroke-linejoin="round"/>
    <rect ${S} x="5" y="30" width="54" height="28" rx="5" fill="#c46f2e"/>
    <path d="M18 32 V56 M46 32 V56" stroke="#ffd23f" stroke-width="5"/>
    <rect x="25.5" y="33" width="13" height="15" rx="3.5" fill="#ffd23f" stroke="${O}" stroke-width="3"/>
    <path d="M32 38 V43" stroke="${O}" stroke-width="3" stroke-linecap="round"/>
    <path fill="#fff" stroke="${O}" stroke-width="2" stroke-linejoin="round" d="M54 0.5 L56 7 L62.5 9 L56 11 L54 17.5 L52 11 L45.5 9 L52 7 Z"/>`,
  tutorial: `<text x="32" y="50" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="50" fill="#fff" stroke="${O}" stroke-width="5" paint-order="stroke">?</text>`,
  rewards: `<rect ${S} x="8" y="26" width="48" height="32" rx="5" fill="#fff"/>
    <rect ${S} x="5" y="17" width="54" height="12" rx="4" fill="#fff"/>
    <path d="M32 17 V58" stroke="#ff4f7b" stroke-width="7"/>
    <path ${S} fill="#ff4f7b" stroke-width="3" d="M32 17 Q22 4 16 10 Q12 16 32 17 Q52 16 48 10 Q42 4 32 17 Z"/>`,
  feedback: `<path ${S} fill="#fff" d="M8 12 H56 V44 H30 L18 56 V44 H8 Z"/>
    <circle cx="22" cy="28" r="3.5" fill="${O}"/><circle cx="32" cy="28" r="3.5" fill="${O}"/><circle cx="42" cy="28" r="3.5" fill="${O}"/>`,
  menu: `<g transform="translate(32 32)">
    ${[0, 45, 90, 135].map((a) => `<rect x="-6" y="-27" width="12" height="54" rx="4" fill="#fff" stroke="${O}" stroke-width="4.5" transform="rotate(${a})"/>`).join('')}
    <circle r="19" fill="#fff"/><circle r="8" fill="#a9b6c8" stroke="${O}" stroke-width="4"/></g>`,
  home: `<path ${S} fill="#ffe7c2" d="M10 30 H54 V58 H10 Z"/>
    <path ${S} fill="#ff6b4a" d="M4 31 L12 12 Q13 9 16 9 H48 Q51 9 52 12 L60 31 Z"/>
    <path d="M14 11 L11 30 M24 10 L23 30 M34 10 V30 M44 10 L45 30 M53 12 L56 30" stroke="#fff" stroke-width="4" opacity=".9"/>
    <path ${S} fill="#ff6b4a" stroke-width="3.5" d="M6 30 Q10.5 37 15 30 Q19.5 37 24 30 Q28.5 37 33 30 Q37.5 37 42 30 Q46.5 37 51 30 Q55.5 37 58 30 Z"/>
    <rect ${S} stroke-width="3.5" x="14" y="40" width="15" height="12" rx="2.5" fill="#8fd8ff"/>
    <path d="M17 49 L25 42" stroke="#fff" stroke-width="2.5" stroke-linecap="round" opacity=".9"/>
    <path ${S} stroke-width="3.5" fill="#b8692e" d="M35 58 V43 Q35 39 39.5 39 H44.5 Q49 39 49 43 V58 Z"/>
    <circle cx="45.5" cy="49.5" r="1.8" fill="#ffd23f"/>
    <path ${S} stroke-width="2.6" fill="#fff" d="M25 18 H37 V22 Q37 26 31 26 Q25 26 25 22 Z"/>
    <path d="M37 19.5 Q40.5 19.5 40.5 21.5 Q40.5 23.5 37 23.5" stroke="${O}" stroke-width="2.2" fill="none"/>`,
  cannon: `<path d="M50 9 L52 3 M56 13 L62 11 M53 6 L58 2" stroke="#ffd23f" stroke-width="3.2" stroke-linecap="round"/>
    <g transform="rotate(-32 32 34)">
    <path ${S} fill="#5b6b82" d="M8 26 Q8 20 14 20 L48 22 V42 L14 44 Q8 44 8 38 Z"/>
    <path d="M14 24 L46 25.5" stroke="#9fb0c8" stroke-width="3.5" stroke-linecap="round"/>
    <rect ${S} stroke-width="3.5" x="20" y="19" width="6" height="26" rx="2" fill="#ffc94d"/>
    <rect ${S} stroke-width="3.5" x="34" y="20" width="6" height="24" rx="2" fill="#ffc94d"/>
    <rect ${S} x="46" y="18" width="9" height="28" rx="3" fill="#7a8aa3"/>
    <ellipse cx="55" cy="32" rx="2" ry="9" fill="${O}"/></g>
    <path ${S} fill="#c46f2e" d="M6 58 L14 42 H36 L42 58 Z"/>
    <path d="M12 54 H38" stroke="#8a4a1c" stroke-width="2.5"/>
    <circle ${S} cx="26" cy="47" r="11" fill="#e8a25a"/>
    <path d="M26 37 V57 M16 47 H36 M19 40 L33 54 M33 40 L19 54" stroke="#8a4a1c" stroke-width="2.4"/>
    <circle cx="26" cy="47" r="3.8" fill="#ffd23f" stroke="${O}" stroke-width="2.6"/>`,
  areas: `<path ${S} fill="#fff" d="M32 58 Q12 36 12 24 A20 20 0 0 1 52 24 Q52 36 32 58 Z"/>
    <circle cx="32" cy="24" r="7" fill="#ff5d5d" stroke="${O}" stroke-width="3.5"/>`,
  potion: (liquid = '#d36bff') => `<path ${S} fill="#eaf6ff" d="M25 10 H39 V21 Q55 28 55 42 A23 20 0 0 1 9 42 Q9 28 25 21 Z"/>
    <path d="M11.5 40 Q20 34 32 38 Q44 42 52.5 38 Q54 52 32 60 Q10 52 11.5 40 Z" fill="${liquid}"/>
    <path d="M11.5 40 Q20 34 32 38 Q44 42 52.5 38" stroke="#fff" stroke-width="2.5" fill="none" opacity=".75" stroke-linecap="round"/>
    <path d="M16 46 Q17 54 26 57" stroke="${O}" stroke-width="2.5" fill="none" opacity=".18" stroke-linecap="round"/>
    <circle cx="38" cy="47" r="3.2" fill="#fff" opacity=".85"/><circle cx="30" cy="52" r="2" fill="#fff" opacity=".85"/><circle cx="43" cy="53" r="1.6" fill="#fff" opacity=".85"/>
    <path d="M17 33 Q20 27 26 25" stroke="#fff" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path ${S} stroke-width="3.5" fill="#d9e9f5" d="M23 12 H41 V17 H23 Z"/>
    <path ${S} stroke-width="3.5" fill="#c58b55" d="M25 3 H39 Q41 3 41 5 V12 H23 V5 Q23 3 25 3 Z"/>
    <path d="M28 5 V10 M33 5 V10" stroke="#9a6534" stroke-width="2"/>
    <path fill="#fff" stroke="${O}" stroke-width="2" stroke-linejoin="round" d="M53 10 L54.6 14.4 L59 16 L54.6 17.6 L53 22 L51.4 17.6 L47 16 L51.4 14.4 Z"/>`,
  bowl: `<path ${S} fill="#fff" d="M6 34 H58 Q56 56 32 56 Q8 56 6 34 Z"/>
    <path ${S} fill="#ffb04a" stroke-width="3.5" d="M18 30 Q28 18 40 26 L48 20 L47 34 L40 30 Q28 38 18 30 Z"/>
    <circle cx="23" cy="28" r="2" fill="${O}"/>`,
  coin: `<circle ${S} cx="32" cy="32" r="26" fill="#ffd23f"/><circle cx="32" cy="32" r="18" fill="none" stroke="#e7a812" stroke-width="4"/>
    <text x="32" y="43" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="30" fill="#fff" stroke="${O}" stroke-width="4" paint-order="stroke">$</text>`,
  fish: `<path ${S} fill="#ffd23f" d="M6 32 Q22 12 42 26 L58 14 L56 32 L58 50 L42 38 Q22 52 6 32 Z"/>
    <circle cx="18" cy="29" r="3" fill="${O}"/>`,
  bag: `<path ${S} fill="#3ccf5a" d="M22 16 Q16 8 22 6 H42 Q48 8 42 16 Q58 28 56 44 Q54 58 32 58 Q10 58 8 44 Q6 28 22 16 Z"/>
    <path d="M22 16 H42" stroke="${O}" stroke-width="4.5" stroke-linecap="round"/>
    <text x="32" y="49" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="28" fill="#fff" stroke="${O}" stroke-width="4" paint-order="stroke">$</text>`,
  crate: `<path ${S} fill="#f2c27a" d="M10 22 L22 10 H56 L44 22 Z"/>
    <path ${S} fill="#c9843f" d="M44 22 L56 10 V46 L44 58 Z"/>
    <rect ${S} x="8" y="22" width="36" height="36" rx="3" fill="#e5a258"/>
    <path d="M8 34 H44 M8 46 H44" stroke="#a8652a" stroke-width="3"/>
    <path d="M50 16 V52" stroke="#9a5a22" stroke-width="3"/>
    <circle cx="26" cy="40" r="11" fill="#ffd23f" stroke="${O}" stroke-width="4"/>
    <text x="26" y="47" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="20" fill="#fff" stroke="${O}" stroke-width="3.5" paint-order="stroke">?</text>`,
  trade: `<path ${S} fill="#4fc3ff" d="M8 24 Q8 14 18 14 H40 V6 L58 20 L40 34 V26 H20 Q18 26 18 28 V30 H8 Z"/>
    <path d="M13 22 Q14 18 19 18 H42" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round" opacity=".8"/>
    <path ${S} fill="#ffb04a" d="M56 40 Q56 50 46 50 H24 V58 L6 44 L24 30 V38 H44 Q46 38 46 36 V34 H56 Z"/>
    <path d="M51 42 Q50 46 45 46 H22" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round" opacity=".8"/>`,
  caviar: `<ellipse ${S} cx="32" cy="44" rx="25" ry="12" fill="#5fb7ff"/>
    <ellipse ${S} cx="32" cy="34" rx="25" ry="11" fill="#e9f5ff"/>
    ${[[20, 32], [27, 29], [34, 31], [41, 28], [24, 37], [31, 36], [38, 37], [45, 34]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3.6" fill="#ff7a2f" stroke="${O}" stroke-width="1.6"/>`).join('')}`,
  // #1070 (Coordinator 11-04): Kibble gets its own bowl of kibble, in the caviar bowl's style, not the HUD's fish bowl
  kibble: `<path ${S} fill="#ff8a4c" d="M6 34 H58 Q56 54 32 56 Q8 54 6 34 Z"/>
    <path d="M12 44 Q32 50 52 44" stroke="#ffb98f" stroke-width="3" fill="none" stroke-linecap="round"/>
    ${[[16, 31], [24, 28], [33, 29], [42, 28], [49, 31], [20, 23], [29, 21], [38, 22], [45, 24], [33, 15]].map(([x, y], i) => `<rect x="${x - 4.5}" y="${y - 3.6}" width="9" height="7.2" rx="3.4" transform="rotate(${(i * 37) % 70 - 35} ${x} ${y})" fill="${i % 3 === 0 ? '#c9894a' : '#b06f36'}" stroke="${O}" stroke-width="1.8"/>`).join('')}
    <path ${S} fill="none" d="M6 34 H58"/>`,
  // #1070: the foods that had no clean picture, and the spin wheel (Derek's live v184 check)
  tuna: `<ellipse ${S} cx="32" cy="46" rx="24" ry="9" fill="#9fb3c8"/>
    <path ${S} fill="#d8e3ee" d="M8 26 V46 Q32 58 56 46 V26 Z"/>
    <ellipse ${S} cx="32" cy="26" rx="24" ry="9" fill="#eef4fa"/>
    <path d="M9 34 Q32 44 55 34 V40 Q32 50 9 40 Z" fill="#5fa8ff"/>
    <path ${S} stroke-width="3" fill="#ff9a8a" d="M22 37 Q30 31 38 36 L44 32 L43 41 L38 38 Q30 43 22 37 Z"/>
    <ellipse cx="32" cy="26" rx="14" ry="4.5" fill="none" stroke="#9fb3c8" stroke-width="2.5"/>`,
  salmon: `<rect ${S} x="8" y="30" width="48" height="22" rx="10" fill="#fff"/>
    <path ${S} fill="#ff8a5c" d="M6 30 Q8 16 24 16 H44 Q58 16 58 30 Q46 36 32 34 Q18 36 6 30 Z"/>
    <path d="M18 20 L24 31 M30 18 L35 32 M42 18 L46 30" stroke="#ffd2bf" stroke-width="3.5" stroke-linecap="round"/>
    <rect x="27" y="29" width="10" height="23" rx="2" fill="#2f4f3a" stroke="${O}" stroke-width="3"/>`,
  sardines: `<path ${S} fill="#8fc7ff" d="M4 36 Q18 18 38 28 L54 18 L52 36 L54 54 L38 44 Q18 54 4 36 Z"/>
    <path d="M10 37 Q24 31 40 36" stroke="#e8f4ff" stroke-width="4" fill="none" stroke-linecap="round"/>
    <circle cx="14" cy="33" r="3" fill="${O}"/>
    <path d="M24 28 Q27 36 24 44" stroke="#5f9fe0" stroke-width="3" fill="none" stroke-linecap="round"/>`,
  moonMilk: `<path ${S} fill="#fff" d="M24 6 H40 V16 Q48 22 48 32 V54 Q48 60 42 60 H22 Q16 60 16 54 V32 Q16 22 24 16 Z"/>
    <rect x="22" y="3" width="20" height="7" rx="2.5" fill="#8f7cff" stroke="${O}" stroke-width="3.5"/>
    <path d="M18 34 H46 V54 Q46 58 42 58 H22 Q18 58 18 54 Z" fill="#dfe8ff"/>
    <path ${S} stroke-width="3" fill="#ffd84a" d="M37 38 A9 9 0 1 0 37 54 A7 7 0 1 1 37 38 Z"/>`,
  starTreat: `<path ${S} fill="#ffd23f" d="M32 4 L40 22 L60 24 L45 37 L49 57 L32 47 L15 57 L19 37 L4 24 L24 22 Z"/>
    <path d="M32 14 L36 25 L48 26" stroke="#fff1a8" stroke-width="3.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="26" cy="34" r="2.6" fill="${O}"/><circle cx="38" cy="34" r="2.6" fill="${O}"/>
    <path d="M28 40 Q32 44 36 40" stroke="${O}" stroke-width="2.6" fill="none" stroke-linecap="round"/>`,
  spin: `<circle ${S} cx="32" cy="34" r="25" fill="#fff"/>
    ${[['#ff5d8f', 0], ['#ffd23f', 60], ['#5fd0ff', 120], ['#7be85a', 180], ['#c07cff', 240], ['#ff9a3c', 300]].map(([c, a]) => `<path d="M32 34 L32 12 A22 22 0 0 1 51.05 23 Z" fill="${c}" transform="rotate(${a} 32 34)"/>`).join('')}
    <circle cx="32" cy="34" r="22" fill="none" stroke="${O}" stroke-width="3"/>
    <circle cx="32" cy="34" r="6" fill="#fff" stroke="${O}" stroke-width="3.5"/>
    <path ${S} stroke-width="3.5" fill="#ff4f4f" d="M25 3 H39 L32 15 Z"/>`,
  // the Decor window's "Your cafe" slots (#964, drawn by Derek's UI-Engineer 11-03 02:30)
  wallpaper: `<path ${S} fill="#7fc4ff" d="M13 18 H51 V54 Q45 60 38.5 55 Q32 50 25.5 55 Q19 60 13 54 Z"/>
    <path d="M23 25 V49 M32 25 V47 M41 25 V49" stroke="#fff" stroke-width="3.5" stroke-linecap="round"/>
    <circle cx="27.5" cy="30" r="2.2" fill="#ff8cc2"/><circle cx="36.5" cy="38" r="2.2" fill="#ff8cc2"/><circle cx="27.5" cy="44" r="2.2" fill="#ff8cc2"/>
    <rect ${S} x="7" y="7" width="50" height="14" rx="7" fill="#fff"/>
    <ellipse cx="54" cy="14" rx="2.6" ry="4.6" fill="#d9d0c4" stroke="${O}" stroke-width="2.4"/>`,
  floor: `<path ${S} fill="#f4c983" d="M14 20 H50 L60 54 H4 Z"/>
    <path d="M14 20 H23 L20.5 37 H9 Z M32 20 H41 L43.5 37 H32 Z M20.5 37 H32 V54 H18 Z M43.5 37 H55 L60 54 H46 Z" fill="#d68f3e"/>
    <path ${S} fill="none" d="M14 20 H50 L60 54 H4 Z"/>
    <path d="M32 20 V54 M9 37 H55 M23 20 L18 54 M41 20 L46 54" stroke="${O}" stroke-width="2.6" stroke-linecap="round"/>`,
  paint: `<path d="M17 20 Q32 1 47 20" fill="none" stroke="${O}" stroke-width="4.5" stroke-linecap="round"/>
    <path ${S} fill="#fff" d="M11 20 H53 L49 56 Q32 62 15 56 Z"/>
    <path ${S} fill="#ff6fae" stroke-width="3.5" d="M11 20 H53 L52.2 27 Q50 34 47.5 27 Q45 42 41 27 Q37 31 33 27 Q29 39 25 27 Q21 32 18 27 Q15 33 11.8 27 Z"/>
    <ellipse cx="32" cy="20" rx="21" ry="4.5" fill="#ff9cc9" stroke="${O}" stroke-width="3.5"/>`,
  spots: `<path ${S} fill="#45cdb4" d="M14 14 Q14 7 21 7 H43 Q50 7 50 14 V34 H14 Z"/>
    <path ${S} fill="#45cdb4" d="M5 28 Q5 21 11.5 21 Q18 21 18 28 V48 H5 Z"/>
    <path ${S} fill="#45cdb4" d="M46 28 Q46 21 52.5 21 Q59 21 59 28 V48 H46 Z"/>
    <rect ${S} x="16" y="31" width="32" height="12" rx="4" fill="#a6f1e2"/>
    <path ${S} fill="#45cdb4" d="M18 42 H46 V48 H18 Z"/>
    <path d="M9 48 V56 M55 48 V56" stroke="${O}" stroke-width="5" stroke-linecap="round"/>`,
  door: `<rect ${S} x="14" y="5" width="36" height="52" rx="6" fill="#c97f45"/>
    <rect x="20" y="11" width="24" height="18" rx="3.5" fill="#9ad8ff" stroke="${O}" stroke-width="3"/>
    <path d="M32 12 V28 M21 20 H43" stroke="${O}" stroke-width="2.2"/>
    <rect x="20" y="34" width="24" height="17" rx="3.5" fill="#b06a35" stroke="#7d4520" stroke-width="2.6"/>
    <circle cx="43.5" cy="33" r="3.4" fill="#ffd23f" stroke="${O}" stroke-width="2.4"/>
    <path d="M7 58.5 H57" stroke="${O}" stroke-width="5" stroke-linecap="round"/>`,
  catflap: `<rect ${S} x="7" y="6" width="50" height="52" rx="6" fill="#c97f45"/>
    <rect ${S} x="16" y="27" width="32" height="27" rx="9" fill="#ffd23f"/>
    <path d="M17 34 H47" stroke="#d69a10" stroke-width="3"/>
    <ellipse cx="32" cy="46.5" rx="5.5" ry="4.3" fill="${O}"/>
    <circle cx="24.5" cy="40.5" r="2.5" fill="${O}"/><circle cx="29" cy="37.8" r="2.5" fill="${O}"/>
    <circle cx="35" cy="37.8" r="2.5" fill="${O}"/><circle cx="39.5" cy="40.5" r="2.5" fill="${O}"/>
    <path d="M12 14 H52" stroke="#a8652a" stroke-width="3" stroke-linecap="round"/>`,
  // #1136 (11-04): the last three glyphs that still drew the old icon sheet: Equip Best, Invite and the lock
  equipBest: `<path ${S} fill="#ffd23f" d="M27 8 Q30 26 46 30 Q30 34 27 56 Q24 34 8 30 Q24 26 27 8 Z"/>
    <path d="M27 17 Q28.5 25 34 27.5" stroke="#fff1a8" stroke-width="3.5" fill="none" stroke-linecap="round"/>
    <path ${S} fill="#fff" stroke-width="3.5" d="M49 5 Q50.5 13 58 14.5 Q50.5 16 49 24 Q47.5 16 40 14.5 Q47.5 13 49 5 Z"/>
    <path ${S} fill="#5fd0ff" stroke-width="3.5" d="M50 38 Q51.2 45 57 46.5 Q51.2 48 50 55 Q48.8 48 43 46.5 Q48.8 45 50 38 Z"/>`,
  invite: `<rect ${S} x="6" y="16" width="52" height="38" rx="6" fill="#fff"/>
    <path d="M9 50 L26 36 M55 50 L38 36" stroke="#d9cfc4" stroke-width="3.5" stroke-linecap="round"/>
    <path ${S} fill="#ffe3ee" d="M7 19 Q7 16 10 16 H54 Q57 16 57 19 L36 37 Q32 40 28 37 Z"/>
    <path ${S} fill="#ff4f7b" stroke-width="3.5" d="M32 46 Q20 38 21 31 Q22 25 27.5 25.5 Q30.5 26 32 29 Q33.5 26 36.5 25.5 Q42 25 43 31 Q44 38 32 46 Z"/>
    <path d="M25.5 30 Q26 28.5 28 28.6" stroke="#fff" stroke-width="2.5" fill="none" stroke-linecap="round" opacity=".85"/>`,
  lock: `<path d="M19 30 V20 A13 13 0 0 1 45 20 V30" fill="none" stroke="${O}" stroke-width="12" stroke-linecap="round"/>
    <path d="M19 30 V20 A13 13 0 0 1 45 20 V30" fill="none" stroke="#a9b6c8" stroke-width="5" stroke-linecap="round"/>
    <path d="M22.5 22 A9.5 9.5 0 0 1 30 12" fill="none" stroke="#e6edf6" stroke-width="2.2" stroke-linecap="round"/>
    <rect ${S} x="9" y="28" width="46" height="31" rx="7" fill="#ffd23f"/>
    <path d="M13 33 H51" stroke="#fff1a8" stroke-width="3" stroke-linecap="round"/>
    <path d="M14 54 H50" stroke="#e7a812" stroke-width="3" stroke-linecap="round"/>
    <path fill="${O}" d="M32 37 A5 5 0 0 1 34.5 46.3 L36 52 H28 L29.5 46.3 A5 5 0 0 1 32 37 Z"/>`,
};
// #1258 (11-04, Derek's drawing): the luck clover. Bright green (#22b04b) with a thin black outline round each leaf
// and the stem, drawn into the art since an emoji can't take an outline; the chip's dark green circle is drawn in Luau.
{
  const K = '#000';
  const leaf = 'M0 0 C-4 -3 -15 -8 -14.5 -17.5 C-14 -24.5 -5 -26 0 -19 C5 -26 14 -24.5 14.5 -17.5 C15 -8 4 -3 0 0 Z';
  const C = 'translate(32 28)';
  window.ICONS.clover = `<path d="M32 30 Q33 47 45 58" fill="none" stroke="${K}" stroke-width="8" stroke-linecap="round"/>
    <path d="M32 30 Q33 47 45 58" fill="none" stroke="#22b04b" stroke-width="4" stroke-linecap="round"/>
    ${[45, 135, 225, 315].map((a) => `<path d="${leaf}" fill="#22b04b" stroke="${K}" stroke-width="2.6" stroke-linejoin="round" transform="${C} rotate(${a}) translate(0 -1.5)"/>`).join('')}`;
}
// #1070: one clean flask per potion, in its colour (Theme.potionColors), as in Derek's 11-04 mockup
for (const [name, liquid] of Object.entries({ potionTip: '#ffc94d', potionLucky: '#6ccb7a', potionSwift: '#5fa8ff', potionSteady: '#8fd3c1', potionBigTip: '#f2b233', potionGoldRush: '#ffe08a', potionQuickBait: '#f5a3c0' })) {
  window.ICONS[name] = window.ICONS.potion(liquid);
}
window.icon = (name, size = 52, arg) => {
  const body = typeof ICONS[name] === 'function' ? ICONS[name](arg) : ICONS[name];
  return `<svg viewBox="0 0 64 64" width="${size}" height="${size}">${body}</svg>`;
};
// #3137 batch 1 (Derek2 2026-11-10: "go through lots of simple plain looking images for ui/buttons and make them
// better"): the Upgrades rows and the cat role slots, which still drew emoji.
Object.assign(window.ICONS, {
  // Upgrades: a round cafe table with a cloth, a cup on it and a chair behind
  tables: `<path ${S} fill="#c97f45" d="M40 20 H52 Q55 20 55 23 V44 H51 V30 H41 Z"/>
    <path d="M45 44 V58 M52 44 V58" stroke="${O}" stroke-width="4.5" stroke-linecap="round"/>
    <ellipse ${S} cx="28" cy="32" rx="24" ry="8" fill="#fff"/>
    <path ${S} fill="#ff8fb3" stroke-width="3.5" d="M4 32 Q6 42 12 42 Q16 37 20 42 Q24 37 28 42 Q32 37 36 42 Q40 37 44 42 Q50 42 52 32 Q40 39 28 39 Q16 39 4 32 Z"/>
    <path d="M28 42 V56" stroke="${O}" stroke-width="7" stroke-linecap="round"/>
    <path d="M28 42 V56" stroke="#b8692e" stroke-width="3" stroke-linecap="round"/>
    <path ${S} fill="#b8692e" stroke-width="3.5" d="M17 58 H39 Q39 54 28 54 Q17 54 17 58 Z"/>
    <path ${S} fill="#fff" stroke-width="3" d="M22 22 H32 V27 Q32 31 27 31 Q22 31 22 27 Z"/>
    <path d="M32 23.5 Q35 23.5 35 25.5 Q35 27.5 32 27.5" stroke="${O}" stroke-width="2.2" fill="none"/>
    <path d="M25 18 Q24 15 26 13 M29 18 Q28 15 30 13" stroke="#fff" stroke-width="2.2" fill="none" stroke-linecap="round"/>`,
  // Upgrades: an espresso machine pouring into a small cup
  espresso: `<rect ${S} x="8" y="6" width="48" height="16" rx="5" fill="#ff6b4a"/>
    <circle cx="18" cy="14" r="3" fill="#ffd23f" stroke="${O}" stroke-width="2"/><circle cx="28" cy="14" r="3" fill="#fff" stroke="${O}" stroke-width="2"/>
    <rect ${S} x="10" y="20" width="44" height="34" rx="4" fill="#d9dee6"/>
    <rect ${S} stroke-width="3.5" x="22" y="22" width="20" height="7" rx="2" fill="#5b6472"/>
    <path d="M30 30 V37 M34 30 V37" stroke="#7a4524" stroke-width="2.6" stroke-linecap="round"/>
    <path ${S} fill="#fff" stroke-width="3.5" d="M23 38 H41 V44 Q41 50 32 50 Q23 50 23 44 Z"/>
    <path d="M41 40 Q46 40 46 43.5 Q46 47 41 47" stroke="${O}" stroke-width="2.6" fill="none"/>
    <rect ${S} stroke-width="3.5" x="6" y="52" width="52" height="7" rx="3" fill="#5b6472"/>`,
  // Upgrades: a catching net, wooden handle and a mesh hoop
  net: `<defs><clipPath id="netHoop"><circle cx="40" cy="24" r="17"/></clipPath><clipPath id="netBag"><path d="M23 26 Q26 54 42 50 Q58 46 57 26 Z"/></clipPath></defs>
    <path d="M8 58 L27 39" stroke="${O}" stroke-width="10" stroke-linecap="round"/>
    <path d="M8 58 L27 39" stroke="#c97f45" stroke-width="5" stroke-linecap="round"/>
    <path ${S} fill="#e8f6ff" d="M22 26 Q24 56 42 52 Q60 47 58 26 Z"/>
    <g clip-path="url(#netBag)" stroke="#5fa8d8" stroke-width="2.4" fill="none">
      <path d="M14 30 L60 56 M14 40 L50 60 M20 22 L64 46 M30 20 L64 38 M64 30 L18 56 M64 40 L28 62 M58 22 L14 46 M48 20 L14 38"/>
    </g>
    <path ${S} fill="none" d="M22 26 Q24 56 42 52 Q60 47 58 26"/>
    <ellipse cx="40" cy="25" rx="19" ry="7" fill="none" stroke="${O}" stroke-width="6.5"/>
    <ellipse cx="40" cy="25" rx="19" ry="7" fill="none" stroke="#ffd23f" stroke-width="3"/>`,
  // Upgrades: the bait bowl, a food bowl with a fish on top
  lureBowl: `<path ${S} fill="#ff8fb3" d="M5 34 H59 Q57 56 32 56 Q7 56 5 34 Z"/>
    <path d="M10 40 Q32 46 54 40" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round" opacity=".8"/>
    <path ${S} fill="#9fb3c8" stroke-width="3.5" d="M12 30 Q24 16 38 24 L50 16 L48 28 L52 38 L38 32 Q24 40 12 30 Z"/>
    <circle cx="21" cy="27" r="2.4" fill="${O}"/>
    <path d="M29 22 Q31 28 29 33" stroke="#7f93a8" stroke-width="2.4" fill="none" stroke-linecap="round"/>
    <circle cx="27" cy="12" r="2" fill="#fff"/><circle cx="41" cy="10" r="2.6" fill="#fff"/>`,
  // Upgrades: a beckoning lucky cat holding a gold coin
  luckyCat: `<path ${S} fill="#fff" d="M14 58 Q10 44 16 36 Q12 28 14 20 L13 6 L24 13 Q32 11 40 13 L51 6 L50 20 Q52 28 48 36 Q54 44 50 58 Z"/>
    <path d="M17 15 L16 9 L22 13 Z M47 15 L48 9 L42 13 Z" fill="#ff9ec4"/>
    <path ${S} fill="#fff" stroke-width="4" d="M48 30 Q54 22 54 12 Q54 7 58 7 Q62 7 61 13 Q60 26 52 34 Z"/>
    <path d="M24 24 Q26 21 28 24 M36 24 Q38 21 40 24" stroke="${O}" stroke-width="2.8" fill="none" stroke-linecap="round"/>
    <path d="M30 28 H34 L32 30.5 Z" fill="#ff6f9a"/>
    <path d="M16 36 Q32 42 48 36" stroke="#ff4f5e" stroke-width="5" fill="none"/>
    <circle cx="32" cy="41" r="3.2" fill="#ffd23f" stroke="${O}" stroke-width="2"/>
    <ellipse ${S} stroke-width="3.5" cx="32" cy="50" rx="10" ry="7" fill="#ffd23f"/>
    <path d="M27 50 H37" stroke="#e7a812" stroke-width="2.6" stroke-linecap="round"/>`,
  // Roles: the barista, a latte cup with a heart and steam
  barista: `<path d="M24 14 Q20 9 24 4 M32 14 Q28 9 32 4 M40 14 Q36 9 40 4" stroke="#fff" stroke-width="3.5" fill="none" stroke-linecap="round"/>
    <path ${S} fill="#fff" d="M10 20 H50 V36 Q50 54 30 54 Q10 54 10 36 Z"/>
    <path ${S} fill="none" stroke-width="5" d="M50 25 Q60 25 60 33 Q60 41 49 42"/>
    <ellipse cx="30" cy="22" rx="17" ry="3.4" fill="#b8692e"/>
    <path fill="#ff6f9a" stroke="${O}" stroke-width="2.4" stroke-linejoin="round" d="M30 44 Q19 36 22 30 Q25 26 30 31 Q35 26 38 30 Q41 36 30 44 Z"/>
    <ellipse ${S} stroke-width="3.5" cx="30" cy="57" rx="24" ry="4" fill="#ffe7c2"/>`,
  // Roles: the waiter, a tray held high with a cake slice on it
  waiter: `<path ${S} fill="#fff" stroke-width="4" d="M27 44 Q24 54 28 60 H38 Q42 54 38 44 Z"/>
    <ellipse ${S} cx="32" cy="40" rx="27" ry="6" fill="#d9dee6"/>
    <path d="M12 39 Q32 43 52 39" stroke="#fff" stroke-width="2.4" fill="none" stroke-linecap="round"/>
    <path ${S} fill="#ffe7c2" stroke-width="3.5" d="M16 36 V24 L46 16 V36 Z"/>
    <path ${S} fill="#ff8fb3" stroke-width="3.5" d="M16 24 L46 16 V21 L16 29 Z"/>
    <path d="M18 31 L44 25" stroke="#ff8fb3" stroke-width="2.6"/>
    <path ${S} fill="#fff" stroke-width="3" d="M34 17 Q38 8 42 15 Z"/>
    <circle cx="38" cy="8" r="3" fill="#ff4f5e" stroke="${O}" stroke-width="2"/>`,
  // Roles: the greeter, a waving cat paw with motion lines
  greeter: `<path d="M8 20 Q5 28 8 36 M14 16 Q11 24 14 32" stroke="#fff" stroke-width="3.5" fill="none" stroke-linecap="round"/>
    <path ${S} fill="#ffb04a" d="M22 60 V40 Q20 30 26 24 Q32 18 40 18 Q50 18 54 26 Q58 34 54 42 L48 60 Z"/>
    <ellipse ${S} stroke-width="3.5" cx="38" cy="36" rx="9" ry="8" fill="#ff9ec4"/>
    <ellipse ${S} stroke-width="3" cx="26" cy="22" rx="4.5" ry="5.5" fill="#ff9ec4"/>
    <ellipse ${S} stroke-width="3" cx="34" cy="16" rx="4.5" ry="5.5" fill="#ff9ec4"/>
    <ellipse ${S} stroke-width="3" cx="44" cy="16" rx="4.5" ry="5.5" fill="#ff9ec4"/>
    <ellipse ${S} stroke-width="3" cx="52" cy="23" rx="4.5" ry="5.5" fill="#ff9ec4"/>`,
  // Roles: the entertainer, a ball of yarn with a loose strand and a sparkle
  entertainer: `<defs><clipPath id="yarnBall"><circle cx="28" cy="34" r="20"/></clipPath></defs>
    <path d="M44 46 Q54 52 50 58 Q46 62 58 60" stroke="${O}" stroke-width="7" fill="none" stroke-linecap="round"/>
    <path d="M44 46 Q54 52 50 58 Q46 62 58 60" stroke="#ff4f7b" stroke-width="3" fill="none" stroke-linecap="round"/>
    <circle ${S} cx="28" cy="34" r="22" fill="#ff6f9a"/>
    <g clip-path="url(#yarnBall)" fill="none" stroke="#ffc2d6" stroke-width="3" stroke-linecap="round">
      <path d="M10 22 Q28 30 46 20 M8 32 Q28 42 48 30 M10 44 Q28 52 46 42 M18 14 Q12 34 22 54 M34 13 Q44 34 36 55"/>
    </g>
    <circle cx="28" cy="34" r="22" fill="none" stroke="${O}" stroke-width="4.5"/>
    <path fill="#ffd23f" stroke="${O}" stroke-width="2" stroke-linejoin="round" d="M52 4 L54 10 L60 12 L54 14 L52 20 L50 14 L44 12 L50 10 Z"/>`,
  // #3136: the Oasis Spa, a round wooden tub with warm water and three rising steam curls
  spa: `<path d="M20 22 Q15 16 20 10 Q25 4 20 -2 M32 22 Q27 16 32 10 Q37 4 32 -2 M44 22 Q39 16 44 10 Q49 4 44 -2" stroke="${O}" stroke-width="7" fill="none" stroke-linecap="round" transform="translate(0 6)"/>
    <path d="M20 22 Q15 16 20 10 Q25 4 20 -2 M32 22 Q27 16 32 10 Q37 4 32 -2 M44 22 Q39 16 44 10 Q49 4 44 -2" stroke="#fff" stroke-width="3.2" fill="none" stroke-linecap="round" transform="translate(0 6)"/>
    <path ${S} fill="#c97f45" d="M6 36 H58 L54 58 H10 Z"/>
    <path d="M9 47 H55" stroke="${O}" stroke-width="3"/>
    <path d="M20 36 V58 M32 36 V58 M44 36 V58" stroke="#8a4f26" stroke-width="2.4"/>
    <ellipse ${S} cx="32" cy="36" rx="27" ry="7" fill="#5fd0e8"/>
    <path d="M18 35 Q24 33 30 35 M36 37 Q42 35 46 37" stroke="#fff" stroke-width="2.6" fill="none" stroke-linecap="round"/>`,
});
// #3137 batch 2 (Derek2 OK'd everything for 11-10 night): the seven places, for the Cat Cannon's cards, the rank-up
// card and the area chips, which still drew emoji. The Ruins' column temple also stands for the Relic Museum.
Object.assign(window.ICONS, {
  // the Park: a round leafy tree over a bench on grass
  park: `<ellipse ${S} cx="32" cy="57" rx="28" ry="5" fill="#7fd36b"/>
    <path d="M30 56 V36" stroke="${O}" stroke-width="10" stroke-linecap="round"/>
    <path d="M30 56 V36" stroke="#a8642e" stroke-width="5" stroke-linecap="round"/>
    <path ${S} fill="#5fb85a" d="M30 6 Q44 6 46 18 Q56 20 54 32 Q52 42 40 40 Q34 46 26 42 Q12 44 10 32 Q8 22 18 18 Q18 6 30 6 Z"/>
    <path d="M20 22 Q24 16 30 16 M38 26 Q44 24 46 30" stroke="#a6e38e" stroke-width="3.5" fill="none" stroke-linecap="round"/>
    <circle cx="22" cy="30" r="2.6" fill="#ff6b6b" stroke="${O}" stroke-width="1.8"/><circle cx="42" cy="18" r="2.6" fill="#ff6b6b" stroke="${O}" stroke-width="1.8"/>
    <rect ${S} stroke-width="3.5" x="38" y="44" width="22" height="5" rx="2" fill="#ff9a4a"/>
    <path d="M41 49 V55 M57 49 V55" stroke="${O}" stroke-width="3.5" stroke-linecap="round"/>`,
  // the Neighbourhood: two little houses side by side, one taller
  neighbourhood: `<path ${S} fill="#ffe7c2" d="M6 34 H30 V58 H6 Z"/>
    <path ${S} fill="#5fa8ff" d="M3 35 L18 20 L33 35 Z"/>
    <rect ${S} stroke-width="3" x="13" y="44" width="9" height="14" rx="2" fill="#b8692e"/>
    <path ${S} fill="#fff6e6" d="M30 26 H58 V58 H30 Z"/>
    <path ${S} fill="#ff6b4a" d="M26 27 L44 8 L62 27 Z"/>
    <rect ${S} stroke-width="3" x="36" y="33" width="8" height="8" rx="1.5" fill="#8fd8ff"/>
    <rect ${S} stroke-width="3" x="47" y="33" width="8" height="8" rx="1.5" fill="#8fd8ff"/>
    <rect ${S} stroke-width="3" x="40" y="46" width="10" height="12" rx="2" fill="#b8692e"/>`,
  // the Woods: two pine trees, the front one bigger
  woods: `<path d="M44 58 V48" stroke="${O}" stroke-width="8" stroke-linecap="round"/><path d="M44 58 V48" stroke="#8a4f26" stroke-width="3.5" stroke-linecap="round"/>
    <path ${S} fill="#2f8f4e" d="M44 10 L56 28 H51 L60 42 H54 L62 50 H26 L34 42 H28 L37 28 H32 Z"/>
    <path d="M24 60 V48" stroke="${O}" stroke-width="9" stroke-linecap="round"/><path d="M24 60 V48" stroke="#a8642e" stroke-width="4" stroke-linecap="round"/>
    <path ${S} fill="#3fae5f" d="M24 4 L38 24 H32 L42 38 H35 L45 50 H3 L13 38 H6 L16 24 H10 Z"/>
    <path d="M18 22 L24 14 M15 36 L22 28 M12 48 L20 40" stroke="#8fe0a0" stroke-width="3" stroke-linecap="round"/>`,
  // the Sewer: a round manhole cover with a grate and a little green glow
  sewer: `<ellipse ${S} cx="32" cy="38" rx="28" ry="20" fill="#6e7f86"/>
    <ellipse ${S} stroke-width="3.5" cx="32" cy="36" rx="20" ry="13" fill="#4b585e"/>
    <path d="M18 31 H46 M14 37 H50 M18 43 H46" stroke="${O}" stroke-width="3" stroke-linecap="round"/>
    <path d="M12 30 Q32 20 52 30" stroke="#a9bac0" stroke-width="3" fill="none" stroke-linecap="round"/>
    <path d="M26 16 Q22 10 27 5 M38 16 Q42 10 37 4" stroke="${O}" stroke-width="6.5" fill="none" stroke-linecap="round"/>
    <path d="M26 16 Q22 10 27 5 M38 16 Q42 10 37 4" stroke="#8fe36b" stroke-width="3" fill="none" stroke-linecap="round"/>`,
  // the Desert: a sandstone pyramid with a sun behind and a dune in front
  desert: `<circle ${S} cx="48" cy="16" r="10" fill="#ffd23f"/>
    <path ${S} fill="#e8a64a" d="M4 52 L28 14 L52 52 Z"/>
    <path ${S} stroke-width="3" fill="#c98432" d="M28 14 L52 52 H34 Z"/>
    <path d="M14 40 H40 M20 30 H34" stroke="#c98432" stroke-width="2.6" stroke-linecap="round"/>
    <path ${S} fill="#ffd38a" d="M2 60 Q16 46 34 52 Q48 56 62 48 V60 Z"/>`,
  // the Ruins: a little temple of four columns under a broken pediment, a vine on one column
  ruins: `<path ${S} fill="#d8e2dc" d="M6 22 L32 6 L58 22 Z"/>
    <path ${S} stroke-width="3.5" fill="#bccbc3" d="M8 22 H56 V28 H8 Z"/>
    <path ${S} stroke-width="3.5" fill="#eef3ef" d="M12 28 H20 V52 H12 Z M24 28 H31 V52 H24 Z M35 28 H42 V52 H35 Z M46 28 H53 V44 L50 41 L53 38 Z"/>
    <path d="M16 31 V49 M27.5 31 V49 M38.5 31 V49" stroke="#bccbc3" stroke-width="2"/>
    <path ${S} stroke-width="3.5" fill="#bccbc3" d="M6 52 H58 V59 H6 Z"/>
    <path d="M23 30 Q28 36 24 42 Q20 47 26 51" stroke="${O}" stroke-width="5.5" fill="none" stroke-linecap="round"/>
    <path d="M23 30 Q28 36 24 42 Q20 47 26 51" stroke="#4e9e78" stroke-width="2.6" fill="none" stroke-linecap="round"/>
    <circle cx="27" cy="36" r="2.2" fill="#6fd39b" stroke="${O}" stroke-width="1.5"/><circle cx="22" cy="45" r="2.2" fill="#6fd39b" stroke="${O}" stroke-width="1.5"/>`,
  // Town Square: a fountain with a water arc on a round plaza
  town: `<ellipse ${S} cx="32" cy="54" rx="28" ry="7" fill="#e9c98f"/>
    <path ${S} fill="#bccbd8" d="M10 44 H54 V50 Q54 55 32 55 Q10 55 10 50 Z"/>
    <ellipse ${S} stroke-width="3.5" cx="32" cy="44" rx="22" ry="5" fill="#5fd0e8"/>
    <path ${S} stroke-width="3.5" fill="#bccbd8" d="M28 44 V30 H36 V44 Z"/>
    <ellipse ${S} stroke-width="3.5" cx="32" cy="30" rx="11" ry="3.5" fill="#d9e3ec"/>
    <path d="M32 26 Q32 10 20 20 Q14 26 16 40 M32 26 Q32 10 44 20 Q50 26 48 40" stroke="${O}" stroke-width="6.5" fill="none" stroke-linecap="round"/>
    <path d="M32 26 Q32 10 20 20 Q14 26 16 40 M32 26 Q32 10 44 20 Q50 26 48 40" stroke="#8fe4ff" stroke-width="3" fill="none" stroke-linecap="round"/>
    <circle cx="32" cy="14" r="3" fill="#8fe4ff" stroke="${O}" stroke-width="2"/>`,
});
// #3137 batch 3: the night's moon (the night line, Night Market) and the open padlock (unlock cards), the last
// emoji in the audit's row 5 (drop, replay and tag already have #2836 pictures)
Object.assign(window.ICONS, {
  // a gold crescent moon with two little stars
  moon: `<path ${S} fill="#ffd23f" d="M40 6 Q20 10 16 30 Q14 50 34 58 Q48 62 58 50 Q40 52 32 40 Q24 26 40 6 Z"/>
    <path d="M24 22 Q20 32 24 42" stroke="#fff1a8" stroke-width="3.5" fill="none" stroke-linecap="round"/>
    <path fill="#fff" stroke="${O}" stroke-width="2" stroke-linejoin="round" d="M50 14 L52 19 L57 20 L52 22 L50 27 L48 22 L43 20 L48 19 Z"/>
    <circle cx="56" cy="34" r="2.6" fill="#fff" stroke="${O}" stroke-width="1.8"/>`,
  // the open gold padlock, its shackle swung up and off to one side
  unlock: `<path d="M22 30 V18 Q22 6 34 6 Q46 6 46 16" stroke="${O}" stroke-width="11" fill="none" stroke-linecap="round"/>
    <path d="M22 30 V18 Q22 6 34 6 Q46 6 46 16" stroke="#c9d3de" stroke-width="5" fill="none" stroke-linecap="round"/>
    <rect ${S} x="8" y="28" width="40" height="30" rx="6" fill="#ffc94d"/>
    <path d="M12 34 H44" stroke="#ffe39a" stroke-width="3" stroke-linecap="round"/>
    <circle cx="28" cy="42" r="4" fill="${O}"/><path d="M28 44 V51" stroke="${O}" stroke-width="4" stroke-linecap="round"/>
    <path fill="#fff" stroke="${O}" stroke-width="2" stroke-linejoin="round" d="M54 30 L56 35 L61 36 L56 38 L54 43 L52 38 L47 36 L52 35 Z"/>`,
});
// #3347 batch 4: the station ring cards that still drew emoji (Relic Museum, Picnic, Yard Sale, Pond, Lost and Found,
// Cat Arcade). The Index Boards reuse Icon_Clean_Index, already uploaded.
Object.assign(window.ICONS, {
  // the Relic Museum: a clay amphora with two handles and a painted band
  museum: `<path d="M22 20 Q10 20 12 32 Q13 38 19 38 M42 20 Q54 20 52 32 Q51 38 45 38" stroke="${O}" stroke-width="9" fill="none" stroke-linecap="round"/>
    <path d="M22 20 Q10 20 12 32 Q13 38 19 38 M42 20 Q54 20 52 32 Q51 38 45 38" stroke="#d9874a" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path ${S} fill="#e89a5a" d="M24 6 H40 V14 Q40 18 44 22 Q54 32 50 46 Q46 58 32 58 Q18 58 14 46 Q10 32 20 22 Q24 18 24 14 Z"/>
    <rect ${S} stroke-width="3.5" x="21" y="3" width="22" height="6" rx="2.5" fill="#f2b27a"/>
    <path d="M14.5 34 H49.5 M15 42 H49" stroke="${O}" stroke-width="2.6"/>
    <path d="M14.5 34 H49.5 L49 42 H15 Z" fill="#2a1a12" opacity=".85"/>
    <path d="M18 38 L22 35 L26 38 L30 35 L34 38 L38 35 L42 38 L46 35" stroke="#ffd23f" stroke-width="2.2" fill="none" stroke-linejoin="round"/>
    <path d="M20 26 Q17 32 18 30" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round" opacity=".6"/>`,
  // the Picnic: a wicker basket with a red gingham cloth peeking out and an arched handle
  picnic: `<path d="M14 30 Q14 6 32 6 Q50 6 50 30" stroke="${O}" stroke-width="10" fill="none" stroke-linecap="round"/>
    <path d="M14 30 Q14 6 32 6 Q50 6 50 30" stroke="#d99a52" stroke-width="4.5" fill="none" stroke-linecap="round"/>
    <path ${S} fill="#fff" d="M10 30 Q16 22 24 28 Q32 20 40 28 Q48 22 54 30 Z"/>
    <path d="M16 26 V30 M24 27 V30 M32 24 V30 M40 27 V30 M48 26 V30" stroke="#ff5a5a" stroke-width="3.2"/>
    <path ${S} fill="#e0a45c" d="M6 30 H58 L52 58 H12 Z"/>
    <path d="M8 38 H56 M10 46 H54 M11.5 53 H52.5" stroke="#a8682c" stroke-width="2.6"/>
    <path d="M20 30 L22 58 M32 30 V58 M44 30 L42 58" stroke="#a8682c" stroke-width="2.6"/>
    <rect ${S} stroke-width="3.5" x="4" y="28" width="56" height="6" rx="3" fill="#c9843e"/>`,
  // the Yard Sale: a price tag on a string with a coin-gold hole ring and a big dollar-free paw
  yardSale: `<path d="M50 6 Q60 4 58 14" stroke="${O}" stroke-width="3" fill="none" stroke-linecap="round"/>
    <path ${S} fill="#ffb15a" d="M30 6 H52 Q58 6 58 12 V34 L30 62 L2 34 Z" transform="rotate(0)"/>
    <circle cx="47" cy="17" r="4.5" fill="#fff" stroke="${O}" stroke-width="3.5"/>
    <ellipse cx="30" cy="38" rx="7" ry="6" fill="#fff" stroke="${O}" stroke-width="2.6"/>
    <circle cx="21" cy="29" r="3.4" fill="#fff" stroke="${O}" stroke-width="2.4"/><circle cx="27" cy="25" r="3.4" fill="#fff" stroke="${O}" stroke-width="2.4"/>
    <circle cx="34" cy="25" r="3.4" fill="#fff" stroke="${O}" stroke-width="2.4"/><circle cx="40" cy="29" r="3.4" fill="#fff" stroke="${O}" stroke-width="2.4"/>`,
  // the Pond: a fishing rod bending over blue water, its red and white bobber floating in a ripple
  pond: `<ellipse ${S} cx="32" cy="50" rx="28" ry="10" fill="#5fc0f0"/>
    <path d="M14 50 Q22 46 30 50 M38 54 Q44 51 50 54" stroke="#fff" stroke-width="2.6" fill="none" stroke-linecap="round"/>
    <path d="M8 58 Q20 10 56 6" stroke="${O}" stroke-width="7.5" fill="none" stroke-linecap="round"/>
    <path d="M8 58 Q20 10 56 6" stroke="#c97f45" stroke-width="3.5" fill="none" stroke-linecap="round"/>
    <path d="M56 6 Q52 26 42 42" stroke="${O}" stroke-width="1.8" fill="none"/>
    <ellipse cx="42" cy="46" rx="9" ry="2.6" fill="none" stroke="#fff" stroke-width="2"/>
    <circle cx="42" cy="42" r="6" fill="#fff" stroke="${O}" stroke-width="3.5"/>
    <path d="M36.2 42 A6 6 0 0 1 47.8 42 Z" fill="#ff4f5e"/>
    <circle cx="42" cy="42" r="6" fill="none" stroke="${O}" stroke-width="3.5"/>
    <rect x="9" y="44" width="7" height="6" rx="2" fill="#5b6b82" stroke="${O}" stroke-width="2.6" transform="rotate(-20 12 47)"/>`,
  // Lost and Found: a striped odd sock with a little sparkle, found again
  lostFound: `<path ${S} fill="#fff" d="M22 4 H44 V34 Q44 40 40 44 L30 54 Q22 62 14 56 Q6 50 12 42 L22 32 Z"/>
    <path d="M22.5 13 H43.5 M22.5 22 H43.5" stroke="#4fc3a0" stroke-width="5"/>
    <rect ${S} stroke-width="3.5" x="20" y="2" width="26" height="7" rx="3" fill="#7ad9bb"/>
    <path d="M13 43 Q9 50 14 55 Q20 60 27 53" stroke="#ff8fb3" stroke-width="6" fill="none" stroke-linecap="round"/>
    <path d="M22 4 H44 V34 Q44 40 40 44 L30 54 Q22 62 14 56 Q6 50 12 42 L22 32 Z" stroke="${O}" stroke-width="4.5" fill="none" stroke-linejoin="round"/>
    <path fill="#ffd23f" stroke="${O}" stroke-width="2" stroke-linejoin="round" d="M54 28 L56 34 L62 36 L56 38 L54 44 L52 38 L46 36 L52 34 Z"/>`,
  // the Cat Arcade: a joystick with a red ball top and two round buttons on a purple base
  arcade: `<path ${S} fill="#9b6bff" d="M6 40 Q6 34 12 34 H52 Q58 34 58 40 V52 Q58 58 52 58 H12 Q6 58 6 52 Z"/>
    <path d="M10 40 H54" stroke="#c4a6ff" stroke-width="3" stroke-linecap="round"/>
    <path d="M22 38 V18" stroke="${O}" stroke-width="9" stroke-linecap="round"/>
    <path d="M22 38 V18" stroke="#c9d3de" stroke-width="4" stroke-linecap="round"/>
    <ellipse ${S} stroke-width="3.5" cx="22" cy="40" rx="9" ry="3.5" fill="#5b4a8a"/>
    <circle ${S} cx="22" cy="14" r="9" fill="#ff4f5e"/>
    <circle cx="19" cy="11" r="2.6" fill="#fff" opacity=".85"/>
    <circle ${S} stroke-width="3.5" cx="40" cy="44" r="5" fill="#ffd23f"/>
    <circle ${S} stroke-width="3.5" cx="51" cy="44" r="5" fill="#4fc3ff"/>
    <path d="M12 52 H52" stroke="#7a52d6" stroke-width="2.6" stroke-linecap="round"/>`,
});
// #4046 quests: the two quest pictures whose emoji (🪙 and 🫙, after Unicode 12) Roblox draws blank
Object.assign(window.ICONS, {
  // Tip piles: the coin stack a customer leaves on the table, three coins high with one leaning on it
  tipPile: `<ellipse cx="30" cy="56" rx="24" ry="5" fill="${O}" opacity=".18"/>
    <ellipse ${S} cx="28" cy="50" rx="20" ry="7" fill="#e7a812"/>
    <path ${S} fill="#ffd23f" d="M8 50 V45 A20 7 0 0 1 48 45 V50 A20 7 0 0 1 8 50 Z"/>
    <path ${S} fill="#ffd23f" d="M10 40 V35 A20 7 0 0 1 50 35 V40 A20 7 0 0 1 10 40 Z"/>
    <path ${S} fill="#ffd23f" d="M7 30 V25 A20 7 0 0 1 47 25 V30 A20 7 0 0 1 7 30 Z"/>
    <ellipse ${S} cx="27" cy="25" rx="20" ry="7" fill="#ffe27a"/>
    <ellipse cx="27" cy="25" rx="12" ry="3.8" fill="none" stroke="#e7a812" stroke-width="2.6"/>
    <path d="M14 48 V50 M22 49.5 V52 M34 49.5 V52 M42 48 V50 M16 38 V40 M24 39.5 V42 M36 39.5 V42 M44 38 V40" stroke="#e7a812" stroke-width="2.2" stroke-linecap="round"/>
    <circle ${S} cx="52" cy="24" r="10" fill="#ffd23f"/>
    <circle cx="52" cy="24" r="5.6" fill="none" stroke="#e7a812" stroke-width="2.4"/>
    <path fill="#fff" stroke="${O}" stroke-width="2" stroke-linejoin="round" d="M50 4 L51.6 8.4 L56 10 L51.6 11.6 L50 16 L48.4 11.6 L44 10 L48.4 8.4 Z"/>`,
  // the Tip Jar: a glass jar of coins with a wooden lid and a paw print label
  tipJar: `<rect ${S} x="18" y="4" width="28" height="9" rx="3" fill="#c97f45"/>
    <path d="M21 8.5 H43" stroke="#e8a66a" stroke-width="2.4" stroke-linecap="round"/>
    <path ${S} fill="#dff3ff" d="M20 13 H44 V17 Q54 21 54 32 V52 Q54 60 46 60 H18 Q10 60 10 52 V32 Q10 21 20 17 Z"/>
    <path fill="#ffd23f" stroke="${O}" stroke-width="3" stroke-linejoin="round" d="M12.5 42 Q20 37 26 40 Q32 36 38 40 Q45 37 51.5 42 V52 Q51.5 57.5 46 57.5 H18 Q12.5 57.5 12.5 52 Z"/>
    <path d="M18 47 Q22 45 26 47 M30 50 Q34 48 38 50 M41 46 Q45 44 48 46" stroke="#e7a812" stroke-width="2.4" fill="none" stroke-linecap="round"/>
    <circle cx="23" cy="37" r="4.4" fill="#ffd23f" stroke="${O}" stroke-width="2.6"/>
    <rect x="22" y="23" width="20" height="13" rx="3" fill="#fff" stroke="${O}" stroke-width="2.6"/>
    <circle cx="32" cy="31.6" r="2.6" fill="#ff8fb3"/>
    <circle cx="27.6" cy="27.8" r="1.4" fill="#ff8fb3"/><circle cx="30.6" cy="26.3" r="1.4" fill="#ff8fb3"/>
    <circle cx="33.6" cy="26.3" r="1.4" fill="#ff8fb3"/><circle cx="36.6" cy="27.8" r="1.4" fill="#ff8fb3"/>
    <path d="M16 24 Q14 34 15 46" stroke="#fff" stroke-width="3.2" fill="none" stroke-linecap="round" opacity=".9"/>`,
});
