// Clean HUD symbols for the 2026-11-03 style mockup: bold white shapes with a thick dark outline, one per button.
const O = '#2a1a12';
const S = `stroke="${O}" stroke-width="4.5" stroke-linejoin="round" stroke-linecap="round" paint-order="stroke"`;
window.ICONS = {
  cats: `<path ${S} fill="#fff" d="M10 56 Q8 30 19 22 L15 6 L29 15 Q32 14 35 15 L49 6 L45 22 Q56 30 54 56 Z"/>
    <circle cx="24" cy="36" r="4" fill="${O}"/><circle cx="40" cy="36" r="4" fill="${O}"/>
    <path d="M29 45 L35 45 L32 49 Z" fill="#ff7aa8" stroke="${O}" stroke-width="2" stroke-linejoin="round"/>`,
  index: `<path ${S} fill="#fff" d="M6 14 Q19 9 32 16 Q45 9 58 14 V52 Q45 47 32 54 Q19 47 6 52 Z"/>
    <path d="M32 17 V52" stroke="${O}" stroke-width="4" stroke-linecap="round"/>
    <path d="M13 22 Q19 20 25 23 M13 30 Q19 28 25 31 M39 23 Q45 20 51 22 M39 31 Q45 28 51 30" stroke="#9bd1ff" stroke-width="3.5" fill="none" stroke-linecap="round"/>`,
  quests: `<rect ${S} x="12" y="6" width="40" height="52" rx="8" fill="#fff"/>
    <path d="M20 22 L26 28 L36 16" stroke="#2fbf4a" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M20 40 H44 M20 48 H38" stroke="${O}" stroke-width="4" stroke-linecap="round"/>`,
  upgrades: `<path ${S} fill="#fff" d="M32 5 L57 31 H43 V58 H21 V31 H7 Z"/>`,
  decor: `<path ${S} fill="#fff" d="M8 30 Q8 21 17 21 H47 Q56 21 56 30 V47 H8 Z"/>
    <path ${S} fill="#ffd6e6" d="M16 32 H48 V42 H16 Z"/>
    <path d="M13 47 V55 M51 47 V55" stroke="${O}" stroke-width="5" stroke-linecap="round"/>`,
  store: `<path ${S} fill="#fff" d="M10 22 H54 L50 58 H14 Z"/>
    <path d="M22 26 V18 Q22 8 32 8 Q42 8 42 18 V26" stroke="${O}" stroke-width="4.5" fill="none" stroke-linecap="round"/>
    <path ${S} fill="#ffd84a" d="M32 32 L35 39 L42 40 L37 45 L38 52 L32 48 L26 52 L27 45 L22 40 L29 39 Z" stroke-width="2.5"/>`,
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
