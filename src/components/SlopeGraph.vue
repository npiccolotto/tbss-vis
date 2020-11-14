<template>
  <svg v-bind:width="width" v-bind:height="height">
    <polyline
      v-for="line in lines"
      v-bind:key="'line' + line.comp1 + '/' + line.comp2"
      v-bind:points="line.points"
      v-bind:stroke-opacity="
        highlightedLine.length > 0 &&
        highlightedLine[0] == line.comp1 &&
        highlightedLine[1] == line.comp2
          ? 0.5
          : 0.25
      "
      stroke="
        black
      "
      fill="none"
      v-bind:stroke-width="line.w"
      v-on:mouseenter="highlightLine(line.comp1, line.comp2)"
      v-on:mouseleave="unhighlightLine()"
    >
      <title>Abs. Correlation: {{ line.d }}</title>
    </polyline>
  </svg>
</template>

<script lang="ts">
import { Vue, Component, Prop } from "vue-property-decorator";
import { scaleLinear, ScaleLinear, scalePow, ScalePower } from "d3-scale";
import range from "lodash-es/range";

function sum(arr: number[]) {
  return (arr || []).reduce((agg, d) => agg + d, 0);
}

class SlopeGraphClass extends Vue {
  @Prop({ default: () => [] }) public elements!: [string[][], string[][]];
  @Prop({ default: () => {} }) public heights!: Record<string, number>; // left and right side heights
  @Prop({ default: 50 }) public width!: number;
  @Prop({ default: 5 }) public maxLineWidth!: number;
  @Prop({ default: () => {} }) public values!: Record<
    string,
    Record<string, number>
  >;

  public highlightedLine: [string, string] | [] = [];
  public clusterGap = 20;
  public height!: number;
  public scaleWidth!: (d: number) => number;

  public scaleY(side: number, component: string) {
    let heightUpToComp = 0;
    for (const [i, group] of this.elements[side].entries()) {
      for (const [j, comp] of group.entries()) {
        if (comp == component) {
          return heightUpToComp + this.heights[comp] / 2;
        }
        heightUpToComp += this.heights[comp];
      }
      heightUpToComp += this.clusterGap;
    }
    return 0;
  }
}

@Component<SlopeGraphClass>({
  computed: {
    height: function() {
      let heights = [0, 0];
      for (const side of [0, 1]) {
        heights[side] += this.elements[side].length * this.clusterGap;
        const comps = this.elements[side].flat();
        for (const comp of comps) {
          heights[side] += this.heights[comp];
        }
      }
      return Math.max(...heights);
    },
    scaleWidth: () =>
      function(d: number) {
        if (d < 0.5) {
          return 0;
        } else if (d < 0.7) {
          return 1;
        } else if (d < 0.9) {
          return 3;
        } else {
          return 6;
        }
      },

    lines: function() {
      const lines = [];
      const margin = 8;

      for (const comp1 of Object.keys(this.values)) {
        const row = this.values[comp1];
        for (const comp2 of Object.keys(row)) {
          const d = Math.abs(this.values[comp1][comp2]);
          const w = this.scaleWidth(d);
          if (w == 0) {
            continue;
          }
          const y1 = this.scaleY(0, comp1);
          const y2 = this.scaleY(1, comp2);
          const points = [
            [0, y1],
            [margin, y1],
            [this.width - margin, y2],
            [this.width, y2]
          ]
            .map(ps => ps.join(","))
            .join(" ");
          lines.push({
            points,
            w,
            y1,
            y2,
            d,
            comp1,
            comp2
          });
        }
      }

      return lines;
    }
  }
})
export default class SlopeGraph extends SlopeGraphClass {
  highlightLine(comp1: string, comp2: string) {
    this.highlightedLine = [comp1, comp2];
  }
  unhighlightLine() {
    this.highlightedLine = [];
  }
}
</script>

<style lang="less" scoped>
polyline {
  pointer-events: visiblePainted;
}
</style>
