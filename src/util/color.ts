import * as cam from "d3-cam02";
import { interpolateGreys } from "d3-scale-chromatic";
import { scaleLinear } from "d3-scale";

const categoryCAM0210: [number, number, number][] = [
  // blue
  [45, 100, 250],
  // orange
  [66, 100, 50],
  // green
  [45, 100, 145],
  // red
  [40, 100, 20]
  // purple
  // brown
  // pink
  // gray
  // lime green
  // turqoise
];

const schemeCategoryCAM0210 = categoryCAM0210.map(jch =>
  cam.jch(...jch).toString()
);

const schemeCategoryBrewer5 = [
  "#e41a1c",
  "#377eb8",
  "#4daf4a",
  "#984ea3",
  "#ff7f00"
];
const brewerCam = schemeCategoryBrewer5.map(hue => {
  const b = cam.jch(hue);
  b.C = 100;
  return b.toString();
});

export function colorLag(lag: number, numLags: number, baseHue?: string) {
  if (baseHue) {
    const b = cam.jch(baseHue);
    b.C = 100 - (lag / numLags) * 100;
    return b;
  }
  return cam.jch(50, 100 - (lag / numLags) * 100, 40);
}

export {
  interpolateGreys as colorDistanceMatrix,
  schemeCategoryBrewer5 as resultColorPalette
};
