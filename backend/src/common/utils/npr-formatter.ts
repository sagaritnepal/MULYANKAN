/**
 * Formats an integer amount of NPR using Nepali lakh/crore digit grouping:
 * 450000 -> "4,50,000", 12345678 -> "1,23,45,678". Never "450,000".
 */
export function formatNpr(amount: number | null | undefined): string {
  if (amount === null || amount === undefined || Number.isNaN(amount)) return 'Rs —';
  const negative = amount < 0;
  const digits = Math.trunc(Math.abs(amount)).toString();

  let grouped: string;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    const last3 = digits.slice(-3);
    const rest = digits.slice(0, -3);
    const pairs = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',');
    grouped = `${pairs},${last3}`;
  }
  return `Rs ${negative ? '-' : ''}${grouped}`;
}
