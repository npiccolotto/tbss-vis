<template>
  <svg v-bind:height="effectiveHeight" v-bind:width="width">
    <g ref="axis">
      <line
        stroke="gray"
        v-bind:x1="0"
        v-bind:x2="width"
        v-bind:y1="effectiveHeight - 1"
        v-bind:y2="effectiveHeight - 1"
      />
    </g>
    <g v-if="maxDistanceToMedoid > 0" />
    <g v-show="zoom > 1" ref="valuescale" />
    <g v-for="(comps, rank) in componentsAggregated" v-bind:key="rank">
      <rect
        v-for="comp in comps"
        v-bind:data-result-id="comp.time_series.result_id"
        v-bind:key="comp.time_series.result_id + comp.time_series.ts_id"
        v-bind:x="comp.x"
        v-bind:width="scales.width"
        v-bind:fill="comp.color"
        v-bind:y="comp.y"
        v-bind:height="comp.height"
        v-bind:opacity="comp.opacity"
        v-on:click="toggleResult(comp.time_series.result_id)"
      >
        <title>
          Correlation diff to most central component: {{ comp.dist_to_medoid }}
        </title>
      </rect>
    </g>
  </svg>
</template>

<script lang="ts">
import { Component, Prop, Vue, Watch } from "vue-property-decorator";
import { scaleLinear, ScaleLinear, scaleBand, ScaleBand } from "d3-scale";
import { extent, histogram, max } from "d3-array";
import range from "lodash-es/range";
import { TimeSeries } from "../types/data";
import { StoreState } from "../types/store";
import isEqual from "lodash-es/isEqual";
import find from "lodash-es/find";
import { format } from "d3-format";
import { axisBottom, axisRight } from "d3-axis";
import { select } from "d3-selection";

class SparkHistogramClass extends Vue {
  @Prop({ default: () => ({}) }) public cluster!: TimeSeries;
  @Prop({ default: 30 }) public height!: number;
  @Prop({ default: 100 }) public width!: number;
  @Prop({ default: 0 }) public max!: number;
  @Prop({ default: () => [1, 1, 1, 1] }) public margin!: [
    number,
    number,
    number,
    number
  ];
  @Prop({ default: 0 }) public zoom!: number;

  public heightScalePerZoomLevel = [1, 2, 4, 8];
  public highlightedResult!: string;
  public scales!: {
    x: ScaleBand<string>;
    o: ScaleLinear<number, number>;
    y: ScaleLinear<number, number>;
  };
  public maxRankFrequency!: number;
  public effectiveHeight!: number;
  public maxDistanceToMedoid!: number;
  public maxDistanceToMedoidAll!: number;
}

@Component<SparkHistogramClass>({
  computed: {
    effectiveHeight() {
      return this.height * this.heightScalePerZoomLevel[this.zoom];
    },
    highlightedResult() {
      return this.$store.state.highlightedResult;
    },
    maxDistanceToMedoid() {
      const state = this.$store.state as StoreState;
      const cluster = find(state.resultClusters, c =>
        isEqual(c.medoid, this.cluster)
      );
      if (!cluster) {
        return 0;
      }
      return Math.max(1, ...cluster.components.map(c => c.dist_to_medoid));
    },
    maxDistanceToMedoidAll() {
      const maxDist = Math.max(
        ...(this.$store.state as StoreState).resultClusters.map(clstr => {
          const localMax = clstr.components.reduce(
            (agg, c) => Math.max(agg, c.dist_to_medoid),
            0
          );
          return localMax;
        })
      );
      return maxDist;
    },
    maxRankFrequency() {
      const maxfreq = Math.max(
        ...(this.$store.state as StoreState).resultMedoidRanks.map(rank => {
          const frequencies = rank.components.reduce(
            (agg, cur) => {
              agg[cur.rank - 1] += 1;
              return agg;
            },
            range(this.$store.state.sources.p).map(() => 0)
          );
          return Math.max(...frequencies);
        })
      );

      return maxfreq;
    },
    componentsAggregated() {
      // TODO slow, takes 60+ ms and is called after mouseenter/mouseleave
      const state = this.$store.state as StoreState;
      const resultColors = this.$store.getters.resultColors;
      const medoidRanks = state.resultMedoidRanks;
      const clusterMedoid = this.cluster;
      if (!clusterMedoid) {
        return {};
      }
      const cluster = find(state.resultClusters, c =>
        isEqual(c.medoid, clusterMedoid)
      );
      const components = find(medoidRanks, mr =>
        isEqual(mr.medoid, clusterMedoid)
      );
      if (!components || !cluster) {
        return {};
      }

      type HistogramElement = {
        time_series: TimeSeries;
        rank: number;
        dist_to_medoid: number;
      };
      type DisplayInfo = {
        x: number;
        y: number;
        height: number;
        color: string;
        opacity: number;
        highlighted: boolean;
      };
      const comps = components.components.reduce(
        (agg: Record<string, HistogramElement[]>, comp) => {
          const rankStr = String(comp.rank);
          if (agg[rankStr] === undefined) {
            agg[rankStr] = [];
          }
          const clusterdist = find(cluster.components, c =>
            isEqual(c.time_series, comp.time_series)
          );
          if (clusterdist) {
            agg[rankStr].push({
              ...comp,
              dist_to_medoid: clusterdist.dist_to_medoid
            });
          }
          return agg;
        },
        {}
      );
      type Foo = DisplayInfo & HistogramElement;
      const displayData: Record<string, Foo[]> = {};
      for (const [ridx, rank] of Object.entries<HistogramElement[]>(comps)) {
        rank.sort(
          (a, b) =>
            this.$store.getters.selectedResults.indexOf(
              a.time_series.result_id
            ) -
            this.$store.getters.selectedResults.indexOf(b.time_series.result_id)
        );
        rank.reverse();
        rank.sort((a, b) => a.dist_to_medoid - b.dist_to_medoid);

        const countPerResult: Record<string, number> = rank.reduce((agg, r) => {
          if (!agg[r.time_series.result_id]) {
            agg[r.time_series.result_id] = 0;
          }
          agg[r.time_series.result_id] += 1;
          return agg;
        }, {} as Record<string, number>);

        displayData[ridx] = rank.reduce((agg: Foo[], r, i, arr) => {
          const resultId = r.time_series.result_id;
          const highlighted = resultId === this.highlightedResult;

          const count = countPerResult[resultId];
          const color =
            this.$store.getters.selectedResults.indexOf(resultId) >= 0
              ? resultColors[resultId]
              : highlighted
              ? this.$store.state.nextColor
              : "black";
          const opacity = this.scales.o(r.dist_to_medoid);
          const x = this.scales.x(ridx) || this.width + 100;
          let height = this.scales.y(0) - this.scales.y(count);
          let y = this.scales.y(count);
          const offsetIfHighlighted = 2;

          if (highlighted) {
            y -= offsetIfHighlighted;
          }

          let anyPriorElementHighlighted = false;
          for (const prior of agg) {
            y -= prior.height;
            if (prior.highlighted) {
              anyPriorElementHighlighted = true;
            }
          }
          if (anyPriorElementHighlighted) {
            y -= 2 * offsetIfHighlighted;
          }

          agg.push({
            ...r,
            x,
            height,
            y,
            highlighted,
            color,
            opacity
          });
          return agg;
        }, []);
      }
      return displayData;
    },
    scales() {
      const x = scaleBand()
        .range([
          this.$props.margin[3],
          this.$props.width - this.$props.margin[1]
        ])
        .domain(range(0, this.$store.state.sources.p + 1).map(String));
      const y = scaleLinear()
        .nice()
        .domain([0, this.maxRankFrequency])
        .range([
          this.effectiveHeight - this.$props.margin[2],
          this.$props.margin[0]
        ]);

      const o = scaleLinear()
        .domain([0, 1])
        .range([1, 0.1]);

      return { x, y, width: x.bandwidth(), o };
    }
  }
})
export default class SparkHistogram extends SparkHistogramClass {
  toggleResult(resultId: string) {
    this.$store.dispatch("toggleSelectedResult", resultId);
  }
  setHighlightedResult(result: string) {
    this.$store.dispatch("setHighlightedResult", result);
  }
  unsetHighlightedResult() {
    this.$store.dispatch("setHighlightedResult", "");
  }
  updated() {
    this.drawAxis();
  }
  mounted() {
    this.drawAxis();
  }

  drawAxis() {
    const valuescale = this.$refs.valuescale as Element;
    const valueAxis = axisRight(this.scales.y)
      .ticks(this.maxRankFrequency)
      .tickFormat(format("d"))
      .tickSize(this.$props.width);
    select(valuescale)
      .call(valueAxis as any)
      .call(g => g.selectAll(".domain").remove())
      .call(g =>
        g
          .selectAll(".tick line")
          .attr("stroke-opacity", 0.15)
          .attr("stroke-dasharray", "2,2")
      )
      .call(g =>
        g
          .selectAll(".tick text")
          .attr("x", 0)
          .attr("font-size", 8)
          .attr("dy", -4)
      );
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style lang="less" scoped="true">
svg rect {
  transition: y linear 100ms;
}
</style>
