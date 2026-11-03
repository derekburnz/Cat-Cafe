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
  home: `<path ${S} fill="#fff" d="M6 32 L32 8 L58 32 H51 V57 H13 V32 Z"/>
    <path ${S} fill="#ff9a3c" stroke-width="3.5" d="M26 57 V42 Q26 37 32 37 Q38 37 38 42 V57 Z"/>`,
  cannon: `<g transform="rotate(-30 30 36)"><rect ${S} x="10" y="24" width="44" height="20" rx="8" fill="#fff"/>
    <rect ${S} x="50" y="21" width="8" height="26" rx="3" fill="#fff"/></g>
    <circle ${S} cx="24" cy="46" r="11" fill="#ffb04a"/><circle cx="24" cy="46" r="3.5" fill="${O}"/>`,
  areas: `<path ${S} fill="#fff" d="M32 58 Q12 36 12 24 A20 20 0 0 1 52 24 Q52 36 32 58 Z"/>
    <circle cx="32" cy="24" r="7" fill="#ff5d5d" stroke="${O}" stroke-width="3.5"/>`,
  potion: (liquid = '#d36bff') => `<path ${S} fill="#fff" d="M25 6 H39 V20 Q54 27 54 41 A22 20 0 0 1 10 41 Q10 27 25 20 Z"/>
    <path d="M14 40 Q20 36 32 39 Q44 42 50 39 A18 16 0 0 1 14 40 Z" fill="${liquid}"/>
    <circle cx="25" cy="44" r="3" fill="#fff" opacity=".8"/><rect x="23" y="3" width="18" height="6" rx="2.5" fill="#c58b55" stroke="${O}" stroke-width="3.5"/>`,
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
  caviar: `<ellipse ${S} cx="32" cy="44" rx="25" ry="12" fill="#5fb7ff"/>
    <ellipse ${S} cx="32" cy="34" rx="25" ry="11" fill="#e9f5ff"/>
    ${[[20, 32], [27, 29], [34, 31], [41, 28], [24, 37], [31, 36], [38, 37], [45, 34]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3.6" fill="#ff7a2f" stroke="${O}" stroke-width="1.6"/>`).join('')}`,
};
window.icon = (name, size = 52, arg) => {
  const body = typeof ICONS[name] === 'function' ? ICONS[name](arg) : ICONS[name];
  return `<svg viewBox="0 0 64 64" width="${size}" height="${size}">${body}</svg>`;
};
