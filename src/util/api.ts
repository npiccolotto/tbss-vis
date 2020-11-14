import { TimeSeries } from "@/types/data";

export function unbox<T = any>(x: [T] | T[]) {
  return x[0];
}

export function unboxObject(x: any): any {
  if (Array.isArray(x)) {
    return unbox(x as [any]);
  }
  if (typeof x === "object" && x !== null) {
    for (const [k, v] of Object.entries(x)) {
      x[k] = unboxObject(v);
    }
  }
  return x;
}

export function indexToTsId(result: string, index: number): string {
  return `${result}#Series ${index + 1}`;
}

export function tsIdToIndex(ts_id: string): number {
  const match = ts_id.match(/(\d+)$/);
  if (match !== null) {
    return parseInt(match[0], 10) - 1;
  }
  throw new Error(`No number found in ${ts_id}`);
}

export function parseTsId(seriesName: string): TimeSeries {
  const [result_id, ts_id] = seriesName.split("#");
  return { result_id, ts_id };
}
