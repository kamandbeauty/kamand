import { bankersRound, type Rial } from './money.js';
import type { CostingMethod, ID, StockMovement } from './types.js';

/**
 * موتور موجودی و بهای تمام‌شده.
 * سه روش: فایفو، لایفو و میانگین موزون.
 * خروجی اصلی: بهای تمام‌شدهٔ کالای فروش‌رفته (COGS) برای محاسبهٔ سود واقعی.
 */

export interface CostLayer {
  qty: number;
  unitCost: Rial;
  date: string;
  sourceId?: ID | null;
}

export class InsufficientStockError extends Error {
  readonly productId: ID;
  readonly requested: number;
  readonly available: number;

  constructor(productId: ID, requested: number, available: number) {
    super(`موجودی کافی نیست: درخواست ${requested}، موجود ${available}`);
    this.name = 'InsufficientStockError';
    this.productId = productId;
    this.requested = requested;
    this.available = available;
  }
}

/**
 * محاسبهٔ بهای خروج از انبار.
 * `allowNegative` برای فروشگاه‌هایی که موجودی را دقیق نگه نمی‌دارند.
 */
export function consumeStock(
  layers: CostLayer[],
  qty: number,
  method: CostingMethod,
  opts: { allowNegative?: boolean; productId?: ID } = {},
): { cogs: Rial; remaining: CostLayer[] } {
  if (qty <= 0) return { cogs: 0, remaining: layers };

  const available = layers.reduce((s, l) => s + l.qty, 0);
  if (qty > available && !opts.allowNegative) {
    throw new InsufficientStockError(opts.productId ?? '', qty, available);
  }

  if (method === 'weighted_average') {
    const totalValue = layers.reduce((s, l) => s + l.unitCost * l.qty, 0);
    const avg = available > 0 ? totalValue / available : 0;
    const cogs = bankersRound(avg * qty);
    const left = available - qty;
    return {
      cogs,
      remaining: left > 0 ? [{ qty: left, unitCost: bankersRound(avg), date: layers[0]?.date ?? '' }] : [],
    };
  }

  // فایفو از ابتدا مصرف می‌کند، لایفو از انتها
  const work = layers.map((l) => ({ ...l }));
  const order = method === 'fifo' ? work : [...work].reverse();

  let need = qty;
  let cogs = 0;
  let lastCost = 0;

  for (const layer of order) {
    if (need <= 0) break;
    const take = Math.min(layer.qty, need);
    cogs += layer.unitCost * take;
    lastCost = layer.unitCost;
    layer.qty -= take;
    need -= take;
  }

  // موجودی منفی: با آخرین بهای شناخته‌شده ارزش‌گذاری می‌شود
  if (need > 0) {
    cogs += lastCost * need;
    const negLayer = { qty: -need, unitCost: lastCost, date: new Date().toISOString().slice(0, 10) };
    return { cogs: bankersRound(cogs), remaining: [negLayer] };
  }

  return { cogs: bankersRound(cogs), remaining: work.filter((l) => l.qty > 0) };
}

export interface StockState {
  qty: number;
  value: Rial;
  layers: CostLayer[];
}

/**
 * بازپخش حرکات انبار یک کالا و محاسبهٔ موجودی و ارزش آن.
 * منبع حقیقت، خودِ حرکات است — هیچ مانده‌ای جداگانه ذخیره نمی‌شود.
 */
export function replayProduct(
  movements: StockMovement[],
  method: CostingMethod,
  opts: { allowNegative?: boolean } = {},
): StockState {
  const sorted = [...movements].sort((a, b) =>
    a.date === b.date ? a.id.localeCompare(b.id) : a.date.localeCompare(b.date),
  );

  let layers: CostLayer[] = [];

  for (const m of sorted) {
    if (m.qty > 0) {
      layers.push({ qty: m.qty, unitCost: m.unitCost, date: m.date, sourceId: m.sourceId });
      if (method === 'weighted_average') {
        const totalQty = layers.reduce((s, l) => s + l.qty, 0);
        const totalVal = layers.reduce((s, l) => s + l.unitCost * l.qty, 0);
        const avg = totalQty > 0 ? bankersRound(totalVal / totalQty) : 0;
        layers = totalQty > 0 ? [{ qty: totalQty, unitCost: avg, date: m.date }] : [];
      }
    } else if (m.qty < 0) {
      const r = consumeStock(layers, -m.qty, method, {
        allowNegative: opts.allowNegative ?? true,
        productId: m.productId,
      });
      layers = r.remaining;
    }
  }

  const qty = layers.reduce((s, l) => s + l.qty, 0);
  const value = bankersRound(layers.reduce((s, l) => s + l.unitCost * l.qty, 0));
  return { qty, value, layers };
}

/** موجودی همهٔ کالاها — گزارش «موجودی کالاها» */
export function stockByProduct(
  movements: StockMovement[],
  method: CostingMethod,
  opts: { allowNegative?: boolean } = {},
): Map<ID, StockState> {
  const grouped = new Map<ID, StockMovement[]>();
  for (const m of movements) {
    const arr = grouped.get(m.productId) ?? [];
    arr.push(m);
    grouped.set(m.productId, arr);
  }
  const out = new Map<ID, StockState>();
  for (const [productId, ms] of grouped) {
    out.set(productId, replayProduct(ms, method, opts));
  }
  return out;
}

/** تبدیل واحد فرعی به اصلی */
export function toMainUnit(qty: number, unit: string, unitMain: string, unitSub?: string, ratio?: number): number {
  if (unit === unitMain || !unitSub || !ratio || ratio <= 0) return qty;
  if (unit === unitSub) return qty / ratio;
  return qty;
}

export interface KardexRow {
  date: string;
  sourceType: string;
  sourceId?: ID | null;
  inQty: number;
  outQty: number;
  unitCost: Rial;
  balanceQty: number;
  balanceValue: Rial;
}

/** کاردکس کالا — لیست ورودی و خروجی با مانده تجمعی */
export function kardex(
  movements: StockMovement[],
  method: CostingMethod,
): KardexRow[] {
  const sorted = [...movements].sort((a, b) =>
    a.date === b.date ? a.id.localeCompare(b.id) : a.date.localeCompare(b.date),
  );
  const rows: KardexRow[] = [];
  const seen: StockMovement[] = [];
  for (const m of sorted) {
    seen.push(m);
    const state = replayProduct(seen, method, { allowNegative: true });
    rows.push({
      date: m.date,
      sourceType: m.sourceType,
      sourceId: m.sourceId,
      inQty: m.qty > 0 ? m.qty : 0,
      outQty: m.qty < 0 ? -m.qty : 0,
      unitCost: m.unitCost,
      balanceQty: state.qty,
      balanceValue: state.value,
    });
  }
  return rows;
}

/**
 * بهای بازگشت کالا به انبار.
 * قاعده: کالای برگشتی باید با همان بهایی که خارج شده بود بازگردد،
 * نه با قیمت فروش. در غیر این صورت ارزش انبار و سود متورم می‌شود.
 */
export function returnUnitCost(
  line: { qty: number; cogs?: Rial; unitPrice: Rial },
  fallbackCost?: Rial,
): Rial {
  if (line.cogs !== undefined && line.qty > 0) {
    return bankersRound(line.cogs / line.qty);
  }
  return fallbackCost ?? line.unitPrice;
}
