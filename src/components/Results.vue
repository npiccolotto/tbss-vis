<template>
  <div class="results">
    <div style="display:flex; flex-direction:column;">
      <div class="input-label">For Components projection, compare</div>
      <select class="small" v-model="similarityMeasure">
        <option disabled value="">How to compare</option>
        <option
          v-for="metric in similarityMeasures"
          v-bind:value="metric"
          v-bind:key="metric"
          >{{ similarityMeasuresLabel[metric] }}</option
        >
      </select>
      <div class="input-label">...of...</div>
      <select class="small" v-model="comparisonStrategy">
        <option disabled value="">What to compare</option>
        <option v-bind:key="strat" v-for="strat in comparisonStrategies">{{
          strat
        }}</option>
      </select>
    </div>
    <div>
      <div>
        <small
          >Component similarity
          <Tooltip
            v-bind:text="
              'Methods are laid out according to the similarity of their components, measured by ' +
                similarityMeasuresLabel[similarityMeasure] +
                '. \nNear methods are generally more similar than methods which are far apart.'
            "
        /></small>
      </div>
      <svg v-bind:width="mapsize + 20" v-bind:height="mapsize + 20">
        <g>
          <text class="axis" transform="rotate(-90,0,0)translate(-90,214)">
            MDS coord. 2 &rightarrow;
          </text>
          <text class="axis" transform="translate(110,214)">
            MDS coord. 1 &rightarrow;
          </text>
        </g>
        <g>
          <rect
            :x="5"
            :y="mapsize + 5"
            width="10"
            height="10"
            fill="white"
            stroke="#ccc"
          />
          <text x="20" :y="mapsize + 14">= {{ resultEmbedding.scale[0] }}</text>
        </g>
        <line
          v-for="(l, lidx) in lines"
          v-bind:key="'h' + lidx"
          v-bind:x1="l * 10"
          v-bind:x2="l * 10"
          v-bind:y1="0"
          v-bind:y2="mapsize"
          v-bind:stroke="
            lidx === Math.floor(lines.length / 2) ? '#ccc' : '#eee'
          "
        ></line>
        <line
          v-for="(l, lidx) in lines"
          v-bind:key="'v' + lidx"
          v-bind:x1="0"
          v-bind:x2="mapsize"
          v-bind:y1="l * 10"
          v-bind:y2="l * 10"
          v-bind:stroke="
            lidx === Math.floor(lines.length / 2) ? '#ccc' : '#eee'
          "
        ></line>
        <circle
          v-for="point in resultEmbedding.embedding"
          v-bind:key="point._row"
          v-bind:cx="point.x"
          v-bind:cy="point.y"
          v-bind:title="point._row"
          v-bind:fill="
            $store.getters.selectedResults.indexOf(point._row) >= 0
              ? resultColors[point._row]
              : highlightedResult === point._row
              ? $store.state.nextColor
              : 'black'
          "
          v-on:mouseenter="setHighlightedResult(point._row)"
          v-on:mouseleave="unsetHighlightedResult()"
          v-on:click="handleSelectedResult(point._row)"
          v-bind:r="
            5 - 4 * (!!highlightedResult ? point.d[highlightedResult] : 0)
          "
        >
          <title>
            {{ point._row.substring(0, 6) }} (MDS coordinates: {{ point.ox }}/{{
              point.oy
            }})
          </title>
        </circle>
      </svg>
    </div>
    <div style="margin-top: 0px;">
      <div>
        <small
          >k1 lag set similarity
          <Tooltip
            v-bind:text="
              'Methods are laid out according to the similarity of their k1 (regular SOBI) lag sets, measured by Manhattan distance. \nNear methods are generally more similar than methods which are far apart.'
            "
        /></small>
      </div>
      <svg v-bind:width="mapsize + 20" v-bind:height="mapsize + 20">
        <g>
          <text class="axis" transform="rotate(-90,0,0)translate(-90,214)">
            MDS coord. 2 &rightarrow;
          </text>
          <text class="axis" transform="translate(110,214)">
            MDS coord. 1 &rightarrow;
          </text>
        </g>
        <g>
          <rect
            :x="5"
            :y="mapsize + 5"
            width="10"
            height="10"
            fill="white"
            stroke="#ccc"
          />
          <text x="20" :y="mapsize + 14">= {{ k1Embedding.scale[0] }}</text>
        </g>
        <line
          v-for="(l, lidx) in lines"
          v-bind:key="'h' + lidx"
          v-bind:x1="l * 10"
          v-bind:x2="l * 10"
          v-bind:y1="0"
          v-bind:y2="mapsize"
          v-bind:stroke="
            lidx === Math.floor(lines.length / 2) ? '#ccc' : '#eee'
          "
        ></line>
        <line
          v-for="(l, lidx) in lines"
          v-bind:key="'v' + lidx"
          v-bind:x1="0"
          v-bind:x2="mapsize"
          v-bind:y1="l * 10"
          v-bind:y2="l * 10"
          v-bind:stroke="
            lidx === Math.floor(lines.length / 2) ? '#ccc' : '#eee'
          "
        ></line>
        <g v-for="point in k1Embedding.embedding" v-bind:key="point._row">
          <g
            v-if="!point.success && point.show"
            v-bind:transform="
              'translate(' + point.x + ',' + point.y + ')rotate(45)'
            "
          >
            <!-- v-bind:opacity="point.b" -->
            <path
              v-bind:d="getSymbol(point, 'k1')"
              v-bind:title="point._row"
              v-bind:fill="
                $store.getters.selectedResults.indexOf(point._row) >= 0
                  ? resultColors[point._row]
                  : highlightedResult === point._row
                  ? $store.state.nextColor
                  : 'black'
              "
              v-on:mouseenter="setHighlightedResult(point._row)"
              v-on:mouseleave="unsetHighlightedResult()"
              v-on:click="handleSelectedResult(point._row)"
            ></path>
          </g>
          <!-- v-bind:opacity="point.b" -->
          <circle
            v-if="point.success && point.show"
            v-bind:cx="point.x"
            v-bind:cy="point.y"
            v-bind:fill="
              $store.getters.selectedResults.indexOf(point._row) >= 0
                ? resultColors[point._row]
                : highlightedResult === point._row
                ? $store.state.nextColor
                : 'black'
            "
            v-on:mouseenter="setHighlightedResult(point._row)"
            v-on:mouseleave="unsetHighlightedResult()"
            v-on:click="handleSelectedResult(point._row)"
            v-bind:r="
              5 -
                4 *
                  (!!highlightedResult &&
                  k1Embedding.embedding.find(e => e._row == highlightedResult)
                    .b > 0
                    ? point.d[highlightedResult]
                    : 0)
            "
            v-bind:title="point._row"
          >
            <title>
              {{ point._row.substring(0, 6) }} (MDS coordinates:
              {{ point.ox }}/{{ point.oy }})
            </title>
          </circle>
        </g>
      </svg>
    </div>
    <div style="margin-top: 0px;">
      <div>
        <small
          >k2 lag set similarity
          <Tooltip
            v-bind:text="
              'Methods are laid out according to the similarity of their k2 (vSOBI) lag sets, measured by Jaccard distance. \nNear methods are generally more similar than methods which are far apart.'
            "
        /></small>
      </div>

      <svg v-bind:width="mapsize + 20" v-bind:height="mapsize + 20">
        <g>
          <text class="axis" transform="rotate(-90,0,0)translate(-90,214)">
            MDS coord. 2 &rightarrow;
          </text>
          <text class="axis" transform="translate(110,214)">
            MDS coord. 1 &rightarrow;
          </text>
        </g>
        <g>
          <rect
            :x="5"
            :y="mapsize + 5"
            width="10"
            height="10"
            fill="white"
            stroke="#ccc"
          />
          <text x="20" :y="mapsize + 14">= {{ k2Embedding.scale[0] }}</text>
        </g>
        <line
          v-for="(l, lidx) in lines"
          v-bind:key="'h' + lidx"
          v-bind:x1="l * 10"
          v-bind:x2="l * 10"
          v-bind:y1="0"
          v-bind:y2="mapsize"
          v-bind:stroke="
            lidx === Math.floor(lines.length / 2) ? '#ccc' : '#eee'
          "
        ></line>
        <line
          v-for="(l, lidx) in lines"
          v-bind:key="'v' + lidx"
          v-bind:x1="0"
          v-bind:x2="mapsize"
          v-bind:y1="l * 10"
          v-bind:y2="l * 10"
          v-bind:stroke="
            lidx === Math.floor(lines.length / 2) ? '#ccc' : '#eee'
          "
        ></line>
        <g v-for="point in k2Embedding.embedding" v-bind:key="point._row">
          <g
            v-if="!point.success && point.show"
            v-bind:transform="
              'translate(' + point.x + ',' + point.y + ')rotate(45)'
            "
          >
            <!-- v-bind:opacity="1 - point.b"-->
            <path
              v-bind:d="getSymbol(point, 'k2')"
              v-bind:title="point._row"
              v-bind:fill="
                $store.getters.selectedResults.indexOf(point._row) >= 0
                  ? resultColors[point._row]
                  : highlightedResult === point._row
                  ? $store.state.nextColor
                  : 'black'
              "
              v-on:mouseenter="setHighlightedResult(point._row)"
              v-on:mouseleave="unsetHighlightedResult()"
              v-on:click="handleSelectedResult(point._row)"
            ></path>
          </g>
          <!-- v-bind:opacity="1 - point.b"-->
          <circle
            v-if="point.success && point.show"
            v-bind:cx="point.x"
            v-bind:cy="point.y"
            v-bind:fill="
              $store.getters.selectedResults.indexOf(point._row) >= 0
                ? resultColors[point._row]
                : highlightedResult === point._row
                ? $store.state.nextColor
                : 'black'
            "
            v-on:mouseenter="setHighlightedResult(point._row)"
            v-on:mouseleave="unsetHighlightedResult()"
            v-on:click="handleSelectedResult(point._row)"
            v-bind:r="
              5 -
                4 *
                  (!!highlightedResult &&
                  k2Embedding.embedding.find(e => e._row == highlightedResult)
                    .b < 1
                    ? point.d[highlightedResult]
                    : 0)
            "
            v-bind:title="point._row"
          >
            <title>
              {{ point._row.substring(0, 6) }} (MDS coordinates:
              {{ point.ox }}/{{ point.oy }})
            </title>
          </circle>
        </g>
      </svg>
    </div>
  </div>
</template>

<script lang="ts">
import TimeSeries from "@/components/TimeSeries.vue";
import { scaleLinear } from "d3-scale";
import { extent, mean } from "d3-array";
import { Component, Prop, Vue } from "vue-property-decorator";
import range from "lodash-es/range";
import { StoreState, StoreGetters } from "../types/store";
import { SOBIResult } from "../types/data";
import { ComponentSortingMetric } from "../types/api";
import { symbol, symbolCircle, symbolCross } from "d3-shape";
import { mapGetters } from "vuex";
import Tooltip from "@/components/Tooltip.vue";

type EmbeddedPoint = {
  _row: string;
  b: number;
  d?: Record<string, number>;
  x: number;
  y: number;
  success: boolean;
};

class ResultsClass extends Vue {
  public highlightedResult!: string;
  public k1Embedding!: { embedding: EmbeddedPoint[]; scale: number };
  public k2Embedding!: { embedding: EmbeddedPoint[]; scale: number };
  public resultEmbedding!: { embedding: EmbeddedPoint[]; scale: number };
  public lines = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19
  ];
}

@Component<ResultsClass>({
  data: function() {
    return {
      mapsize: 200,
      similarityMeasures: ["doi", "shape"],
      similarityMeasuresLabel: {
        doi: "interestingness",
        shape: "abs. correlation diff."
      }
    };
  },
  components: { TimeSeries, Tooltip },
  computed: {
    ...mapGetters(["resultColors"]),
    similarityMeasure: {
      get() {
        return (this.$store.state as StoreState).resultEmbeddingConfig
          .similarityMeasure;
      },
      set(n: string) {
        this.$store.dispatch("setResultEmbeddingConfig", {
          similarityMeasure: n
        });
      }
    },
    comparisonStrategies() {
      return [
        "all components",
        ...range(this.$store.state.sources.p).map(i => `component ${i + 1}`)
      ];
    },
    comparisonStrategy: {
      get() {
        const config = (this.$store.state as StoreState).resultEmbeddingConfig;
        if (config.comparisonStrategy === "all") {
          return "all components";
        } else {
          return `component ${config.compareRank}`;
        }
      },
      set(n: string) {
        if (n === "all components") {
          this.$store.dispatch("setResultEmbeddingConfig", {
            comparisonStrategy: "all",
            compareRank: 0
          });
        } else {
          const compareRank = parseInt(n.match(/\d+/)![0], 10);
          this.$store.dispatch("setResultEmbeddingConfig", {
            comparisonStrategy: "rank",
            compareRank: compareRank
          });
        }
      }
    },
    highlightedResult() {
      return this.$store.state.highlightedResult;
    },
    results() {
      return (this.$store.state as StoreState).results;
    },
    k1Embedding() {
      const state = this.$store.state as StoreState;

      const embedding = state.parameterEmbeddings.k1.embedding;
      const margin = 0;
      const x = scaleLinear()
        .domain([-this.$data.mapsize / 2, this.$data.mapsize / 2])
        .range([margin, this.$data.mapsize - margin]);
      const y = scaleLinear()
        .domain([-this.$data.mapsize / 2, this.$data.mapsize / 2])
        .range([margin, this.$data.mapsize - margin]);

      const result = embedding
        .filter(
          point =>
            !!state.results[point._row] &&
            !!state.results[point._row].parameters
        )
        .map(point => ({
          ...point,
          success: state.results[point._row].parameters.success,
          show: state.results[point._row].parameters.b > 0,
          b: state.results[point._row].parameters.b,
          d: state.parameterEmbeddings.k1.distances.find(
            r => r._row === point._row
          ),
          ox: point.ox,
          oy: point.oy,
          x: x(point.x),
          y: y(point.y)
        }));
      return { embedding: result, scale: state.parameterEmbeddings.k1.scale };
    },
    k2Embedding() {
      const state = this.$store.state as StoreState;

      const embedding = state.parameterEmbeddings.k2.embedding;
      const margin = 0;
      const x = scaleLinear()
        .domain([-this.$data.mapsize / 2, this.$data.mapsize / 2])
        .range([margin, this.$data.mapsize - margin]);
      const y = scaleLinear()
        .domain([-this.$data.mapsize / 2, this.$data.mapsize / 2])
        .range([margin, this.$data.mapsize - margin]);

      const result = embedding
        .filter(
          emb =>
            !!state.results[emb._row] && !!state.results[emb._row].parameters
        )
        .map(point => ({
          ...point,
          success: state.results[point._row].parameters.success,
          show: state.results[point._row].parameters.b < 1,
          b: state.results[point._row].parameters.b,
          d: state.parameterEmbeddings.k2.distances.find(
            r => r._row === point._row
          ),
          ox: point.ox,
          oy: point.oy,
          x: x(point.x),
          y: y(point.y)
        }));
      return { embedding: result, scale: state.parameterEmbeddings.k2.scale };
    },
    resultEmbedding() {
      const state = this.$store.state as StoreState;

      const embedding = state.resultEmbeddings.embedding;
      const margin = 0;
      const x = scaleLinear()
        .domain([-this.$data.mapsize / 2, this.$data.mapsize / 2])
        .range([margin, this.$data.mapsize - margin]);
      const y = scaleLinear()
        .domain([-this.$data.mapsize / 2, this.$data.mapsize / 2])
        .range([margin, this.$data.mapsize - margin]);

      const result = embedding
        .filter(
          emb =>
            !!state.results[emb._row] && !!state.results[emb._row].parameters
        )
        .map(point => ({
          ...point,
          success: state.results[point._row].parameters.success,
          show: true,
          d: state.resultEmbeddings.distances.find(r => r._row === point._row),
          ox: point.ox,
          oy: point.oy,
          x: x(point.x),
          y: y(point.y)
        }));
      return { embedding: result, scale: state.resultEmbeddings.scale };
    }
  }
})
export default class Results extends ResultsClass {
  getSymbol(point: any, parameter: "k1" | "k2" | "result") {
    const state = this.$store.state as StoreState;
    let size = 50;
    if (this.highlightedResult) {
      let d = 0;
      switch (parameter) {
        case "k1":
          d =
            this.k1Embedding.embedding.find(
              p => p._row === this.highlightedResult
            )!.b > 0
              ? point.d[this.highlightedResult]
              : 0;
          break;
        case "k2":
          d =
            this.k2Embedding.embedding.find(
              p => p._row === this.highlightedResult
            )!.b < 1
              ? point.d[this.highlightedResult]
              : 0;
          break;
        case "result":
          d =
            this.highlightedResult in point.d
              ? point.d[this.highlightedResult]
              : 0;
          break;
      }
      size = 50 - 45 * d;
    }

    const s = symbol()
      .type(() => (point.success ? symbolCircle : symbolCross))
      .size(size);
    return s();
  }
  mounted() {
    this.$store.dispatch("fetchResultComparisonData");
    this.$store.dispatch("fetchResults");
  }

  setHighlightedResult(id: string) {
    this.$store.dispatch("setHighlightedResult", id);
  }

  unsetHighlightedResult() {
    this.$store.dispatch("setHighlightedResult", "");
  }

  handleSelectedResult(id: string) {
    this.$store.dispatch("toggleSelectedResult", id);
  }
}
</script>

<style scoped lang="less">
.results {
  display: flex;
  flex-direction: column;
}
svg {
  //border: 1px solid #ddd;

  text {
    font-size: 12px;
    opacity: 0.5;

    &.axis {
      opacity: 0.25;
    }
  }
  circle {
    // property name | duration | timing function | delay
    transition: cx 250ms linear 150ms, cy 250ms linear 150ms, r 100ms linear 0ms;
  }
  circle,
  path {
    cursor: pointer;
  }
}
</style>
