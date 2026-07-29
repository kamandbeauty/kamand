import { formatJalali } from './jalali.js';
import { formatMoney } from './money.js';

/**
 * خروجی گرفتن از داده — پشتوانهٔ عملی تعهد «دادهٔ کاربر گروگان گرفته نمی‌شود».
 * این ماژول هیچ وابستگی‌ای به وضعیت اشتراک ندارد و نباید داشته باشد.
 */

/** فرار دادن مقدار برای CSV مطابق RFC 4180 */
function csvCell(value: unknown): string {
  if (value === null || value === undefined) return '';
  const s = String(value);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export interface Column<T> {
  key: string;
  header: string;
  value: (row: T) => unknown;
}

export function toCSV<T>(rows: T[], columns: Column<T>[]): string {
  const head = columns.map((c) => csvCell(c.header)).join(',');
  const body = rows.map((r) => columns.map((c) => csvCell(c.value(r))).join(',')).join('\r\n');
  // BOM برای اینکه اکسل فارسی را درست بخواند
  return `\uFEFF${head}\r\n${body}`;
}

/**
 * تولید فایل SpreadsheetML — اکسل بدون نیاز به کتابخانهٔ خارجی.
 * راست‌به‌چپ و با پشتیبانی از چند برگه.
 */
export interface Sheet<T = Record<string, unknown>> {
  name: string;
  rows: T[];
  columns: Column<T>[];
}

function xmlEscape(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export function toExcelXML(sheets: Sheet<never>[]): string {
  const body = sheets
    .map((sheet) => {
      const header = sheet.columns
        .map((c) => `<Cell ss:StyleID="hdr"><Data ss:Type="String">${xmlEscape(c.header)}</Data></Cell>`)
        .join('');

      const rows = (sheet.rows as unknown[])
        .map((r) => {
          const cells = sheet.columns
            .map((c) => {
              const v = c.value(r as never);
              const isNum = typeof v === 'number' && Number.isFinite(v);
              const type = isNum ? 'Number' : 'String';
              const text = v === null || v === undefined ? '' : xmlEscape(String(v));
              return `<Cell><Data ss:Type="${type}">${text}</Data></Cell>`;
            })
            .join('');
          return `<Row>${cells}</Row>`;
        })
        .join('');

      return `<Worksheet ss:Name="${xmlEscape(sheet.name.slice(0, 31))}">
<Table><Row>${header}</Row>${rows}</Table>
<WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel"><DisplayRightToLeft/></WorksheetOptions>
</Worksheet>`;
    })
    .join('');

  return `<?xml version="1.0" encoding="UTF-8"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
<Styles><Style ss:ID="hdr"><Font ss:Bold="1"/><Interior ss:Color="#EEEEEE" ss:Pattern="Solid"/></Style></Styles>
${body}</Workbook>`;
}

/** خروجی کامل و خام همهٔ داده‌ها — «دانلود کل اطلاعات من» */
export interface FullBackup {
  format: 'javid-backup';
  version: number;
  exportedAt: string;
  business: unknown;
  data: Record<string, unknown[]>;
}

export function createBackup(business: unknown, data: Record<string, unknown[]>): FullBackup {
  return {
    format: 'javid-backup',
    version: 1,
    exportedAt: new Date().toISOString(),
    business,
    data,
  };
}

export function serializeBackup(backup: FullBackup): string {
  return JSON.stringify(backup, null, 2);
}

export function parseBackup(text: string): FullBackup {
  const parsed = JSON.parse(text) as FullBackup;
  if (parsed.format !== 'javid-backup') throw new Error('فایل پشتیبان معتبر نیست');
  if (parsed.version > 1) throw new Error('این فایل پشتیبان با نسخهٔ جدیدتری ساخته شده است');
  return parsed;
}

/** ستون‌های آماده برای خروجی‌های رایج */
export const commonFormatters = {
  date: (iso: string | null | undefined) => (iso ? formatJalali(new Date(iso), 'short') : ''),
  money: (v: number) => formatMoney(v, { persian: false }),
};
