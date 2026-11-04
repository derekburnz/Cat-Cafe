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
};
// #1070: one clean flask per potion, in its colour (Theme.potionColors), as in Derek's 11-04 mockup
for (const [name, liquid] of Object.entries({ potionTip: '#ffc94d', potionLucky: '#6ccb7a', potionSwift: '#5fa8ff', potionSteady: '#8fd3c1', potionBigTip: '#f2b233', potionGoldRush: '#ffe08a', potionQuickBait: '#f5a3c0' })) {
  window.ICONS[name] = window.ICONS.potion(liquid);
}
window.icon = (name, size = 52, arg) => {
  const body = typeof ICONS[name] === 'function' ? ICONS[name](arg) : ICONS[name];
  return `<svg viewBox="0 0 64 64" width="${size}" height="${size}">${body}</svg>`;
};
