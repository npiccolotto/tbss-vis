<template>
  <svg v-bind:width="width" v-bind:height="height">
    <g v-if="effectiveShowLabel">
      <g
        v-for="(window, widx) in windowedLags"
        v-bind:key="'label' + widx"
        v-bind:data-widx="widx"
        v-bind:data-min="window.min"
        v-bind:data-max="window.max"
        v-bind:transform="
          'rotate(-90)translate(' +
            -(effectiveShowLabel ? legendHeight : 0) +
            ',' +
            widx * markerSize[0] +
            ')'
        "
      >
        <text
          v-bind:fill="window.hasLagInBin ? 'black' : 'gray'"
          text-anchor="end"
          v-bind:x="markerSize[1] - 3"
          v-bind:y="markerSize[0] - 3"
        >
          {{ window.min }}
        </text>
      </g>
    </g>
    <g
      v-for="(window, widx) in windowedLags"
      v-bind:key="'window' + widx"
      v-bind:data-widx="widx"
      v-bind:data-min="window.min"
      v-bind:data-max="window.max"
    >
      <g
        v-for="(r, ridx) in window.lags"
        v-bind:key="ridx"
        v-bind:data-ridx="ridx"
        v-bind:class="{ interactive }"
        v-bind:transform="
          'rotate(-90)translate(' +
            (-(ridx + 1) * markerSize[1] -
              (effectiveShowLabel ? legendHeight : 0)) +
            ',' +
            widx * markerSize[0] +
            ')'
        "
        v-bind:data-lag="r.lag"
      >
        <rect
          v-on:click="handleClick(ridx, r.lag)"
          v-on:mouseenter="handleHover(r.lag)"
          fill="white"
          stroke="white"
          v-bind:stroke-width="1"
          v-bind:width="markerSize[1]"
          v-bind:height="markerSize[0]"
        >
          <title v-if="r.hasValue">
            {{ r.title }}
          </title>
        </rect>
        <rect
          v-on:click="handleClick(ridx, r.lag)"
          v-on:mouseenter="handleHover(r.lag)"
          v-if="r.lag > 0"
          v-bind:fill="lagColor(r.color, r.lag)"
          stroke="white"
          v-bind:stroke-width="1"
          v-bind:width="barScale(r.numLagsInBin)"
          v-bind:height="markerSize[0]"
        >
          <title v-if="r.hasValue">
            {{ r.title }}
          </title>
        </rect>
      </g>
    </g>
    <g>
      <text
        v-for="(v, i) in valuesWithoutLags"
        v-bind:key="i"
        v-bind:fill="v[1].color"
        v-bind:y="
          markerSize[1] * (i + values.length + (effectiveShowLabel ? 1 : 0)) -
            markerSize[1] / 2
        "
      >
        unused
      </text>
    </g>
  </svg>
</template>

<script lang="ts">
import { Vue, Component, Prop } from "vue-property-decorator";
import { colorLag } from "@/util/color";
import pluralize from "pluralize";
import { scaleLinear, ScaleLinear } from "d3-scale";
import { extent } from "d3-array";
import { StoreState } from "../types/store";

function between(min: number, max: number) {
  return function(x: number) {
    return min <= x && x <= max;
  };
}

class LagSetClass extends Vue {
  @Prop({ default: () => [12, 30] }) public markerSize!: [number, number];
  @Prop({ default: () => [] }) public values!: {
    value: number[];
    color: string;
  }[];
  @Prop({ default: 0 }) public scaleMaxToExternal!: number;
  @Prop({ default: 0 }) public showLabel!: number;
  @Prop({ default: false }) public interactive!: boolean;
  @Prop({ default: 0 }) public skipEmptyBins!: number;
  @Prop({ default: 0 }) public binSize!: number;
  @Prop({ default: true }) public canBin!: boolean;
  @Prop({ default: () => [2, 2, 2, 2] }) public margin!: [
    number,
    number,
    number,
    number
  ];

  public globalLagSetWindow!: number;
  public windowedLags!: {
    min: number;
    max: number;
    lags: { numLagsInBin: number; color: string; title: string; lag: number }[];
  }[];
  public barScale!: ScaleLinear<number, number>;
  public legendHeight = 30;
  public effectiveSkipEmptyBins!: boolean;
  public effectiveBinSize!: number;
  public effectiveShowLabel!: boolean;
  public totalLags!: number[];
}

@Component<LagSetClass>({
  computed: {
    effectiveBinSize() {
      if (this.binSize > 0) {
        return this.binSize;
      }
      const maxLag = this.$store.state.maximumLag;
      return this.canBin ? Math.min(maxLag, this.globalLagSetWindow) : 1;
    },
    effectiveSkipEmptyBins() {
      if (this.skipEmptyBins > 0) {
        return this.skipEmptyBins === 1 ? true : false;
      }
      return this.$store.state.globalSkipEmptyLagBins;
    },
    effectiveShowLabel() {
      if (this.showLabel > 0) {
        return this.showLabel === 1 ? true : false;
      }
      return this.$store.state.globalShowLagNumbers;
    },
    barScale() {
      const v = this.windowedLags
        .map(wl => wl.lags.map(l => l.numLagsInBin))
        .flat();
      let [min, max] = extent(v);
      if (this.scaleMaxToExternal > 0) {
        max = this.scaleMaxToExternal;
      }
      const y = scaleLinear()
        .domain([0, max!])
        .range([1, this.markerSize[1]]);
      return y;
    },
    width() {
      return this.windowedLags.length * this.markerSize[0];
    },
    height() {
      return (
        (this.values.length + (this.effectiveShowLabel ? 1 : 0)) *
        this.markerSize[1]
      );
    },
    globalLagSetWindow() {
      return (this.$store.state as StoreState).globalLagSetWindow;
    },
    totalLags() {
      return this.values.map(v => v.value.length);
    },
    valuesWithoutLags() {
      return this.values
        .map((v, i) => [v.value.length, v, i])
        .filter(([c]) => c === 0)
        .map(([c, v, i]) => [i, v]);
    },
    windowedLags() {
      const maxLag = this.$store.state.maximumLag;
      const window = this.effectiveBinSize;
      let numBins = maxLag;
      if (window > 1) {
        numBins = Math.floor(maxLag / window);
        if (maxLag % window > 0) {
          numBins = numBins + 1;
        }
      }
      let result = [];
      for (let bin = 0; bin < numBins; bin++) {
        const binStart = bin * window + 1;
        const binEnd = Math.min(maxLag, (bin + 1) * window);
        const isBetween = between(binStart, binEnd);
        const hasLagInBin = this.values.some(res => {
          return res.value.filter(x => isBetween(x)).length > 0;
        });
        if (!hasLagInBin && this.effectiveSkipEmptyBins) {
          continue;
        }

        result.push({
          min: binStart,
          max: binEnd,
          hasLagInBin,
          lags: this.values.map((res, i) => {
            const lagsInBin = res.value.filter(x => isBetween(x));
            const lag = Math.min(...lagsInBin);
            const title =
              window === 1
                ? `${lag}`
                : `${binStart}-${binEnd}: ${lagsInBin.length} lags`;
            return {
              title,
              color: res.color,
              numLagsInBin: lagsInBin.length,
              hasValue: lag !== Infinity,
              lag: lag === Infinity ? 0 : lag
            };
          })
        });
      }
      result = result.map((r, i) => ({
        ...r,
        lags: r.lags.filter((v, j) => this.totalLags[j] > 0)
      }));
      return result;
    }
  }
})
export default class LagSet extends LagSetClass {
  lagColor(hue: string, lag: number) {
    return colorLag(lag, this.$store.state.maximumLag, hue);
  }

  handleClick(resultIndex: number, lag: number) {
    this.$emit("click-lag", { resultIndex, lag });
  }

  handleHover(lag: number) {
    this.$store.dispatch("setHighlightedLag", lag);
  }
}
</script>

<style lang="less" scoped>
text {
  font-family: monospace;
  font-size: 10px;
  user-select: none;
}

.interactive {
  rect,
  text {
    cursor: pointer;
  }
}
</style>
