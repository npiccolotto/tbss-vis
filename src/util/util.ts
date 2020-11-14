import range from "lodash-es/range";
import { format } from "d3-format";

export function newMatrix<T>(
  nrow: number,
  ncol: number = nrow,
  init: () => any = () => ({})
) {
  return range(nrow).map(() => range(ncol).map(() => init())) as T[][];
}

export type Bin = {
  binStart: number;
  binEnd: number;
  binWidth: number;
  lagsInBin: number[];
};

export function binLagSet(
  lagset: number[],
  windowSize: number,
  maxLag: number
) {
  const result = [] as Bin[];
  let numBins = maxLag;
  if (windowSize > 1) {
    numBins = Math.floor(maxLag / windowSize);
    if (maxLag % windowSize > 0) {
      numBins = numBins + 1;
    }
  }
  for (let bin = 0; bin < numBins; bin++) {
    const binStart = bin * windowSize + 1;
    const binEnd = Math.min(maxLag, (bin + 1) * windowSize);
    const lagsInBin = lagset.filter(lag => lag >= binStart && lag <= binEnd);
    result.push({
      binStart,
      binEnd,
      binWidth: binEnd - binStart + 1,
      lagsInBin
    });
  }
  return result;
}

function _formatInteger(padTo: number = 2) {
  return format(`0=${padTo}`);
}

let formatInteger = _formatInteger(2);

function sortNumbersAsc(x: number, y: number) {
  return x - y;
}

export { formatInteger, sortNumbersAsc };
