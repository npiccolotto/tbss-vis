<template>
  <div>
    <table>
      <thead>
        <tr>
          <th></th>
          <th>Method</th>
          <th>k2 <Tooltip v-bind:text="'Lags for vSOBI'" /></th>
          <th>
            b
            <Tooltip
              v-bind:text="
                'Weight between k1 and k2 lag sets: 0 only uses vSOBI, 1 only SOBI'
              "
            />
          </th>
          <th>k1 <Tooltip v-bind:text="'Lags for SOBI'" /></th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-on:mouseenter="setHighlightedResult(id)"
          v-on:mouseleave="unsetHighlightedResult()"
          v-bind:key="id"
          v-for="id in $store.getters.results"
        >
          <td
            class="clickable"
            v-bind:title="success[id] ? 'Converged' : 'Did not converge'"
            v-on:click="toggleResult(id)"
            v-bind:style="{
              backgroundColor:
                $store.getters.selectedResults.indexOf(id) >= 0
                  ? $store.getters.resultColors[id]
                  : $store.state.highlightedResult === id
                  ? $store.state.nextColor
                  : 'white'
            }"
          ></td>
          <td
            class="clickable"
            v-bind:title="success[id] ? 'Converged' : 'Did not converge'"
            v-bind:style="{
              background: success[id] ? '#eee' : 'white'
            }"
            v-on:click="toggleResult(id)"
          >
            {{ id.substr(0, 6) }}
          </td>
          <td class="parameters__k2">
            <LagSet
              v-if="!!k2s[id]"
              v-bind:binSize="500"
              v-bind:skipEmptyBins="2"
              v-bind:scaleMaxToExternal="
                $store.getters.maxParamBinValue(id, 500)
              "
              v-bind:showLabel="2"
              v-bind:markerSize="[6, 24]"
              v-bind:values="k2s[id] ? [k2s[id]] : []"
            />
            <span v-else style="font-size:10px; color: gray;">unused</span>
            <!-- <Histogram
              v-bind:numBins="lagBinCount"
              v-bind:maxHeightValue="
                $store.getters.maxParamBinValue(id, lagBinCount)
              "
              v-bind:values="
                $store.state.results[id].parameters.b < 1
                  ? $store.state.results[id].parameters.k2
                  : []
              "
            /> -->
          </td>
          <td class="parameters__b">
            <VerticalWeight
              v-bind:weight="$store.state.results[id].parameters.b"
              v-bind:color="$store.state.results[id].parameters.b"
            />
          </td>
          <td class="parameters__k1">
            <LagSet
              v-if="!!k1s[id]"
              v-bind:binSize="500"
              v-bind:skipEmptyBins="2"
              v-bind:scaleMaxToExternal="
                $store.getters.maxParamBinValue(id, 500)
              "
              v-bind:showLabel="2"
              v-bind:markerSize="[6, 24]"
              v-bind:values="k1s[id] ? [k1s[id]] : []"
            /><span v-else style="font-size:10px; color: gray;">unused</span>
            <!--  <Histogram
              v-bind:numBins="lagBinCount"
              v-bind:maxHeightValue="
                $store.getters.maxParamBinValue(id, lagBinCount)
              "
              v-bind:values="
                $store.state.results[id].parameters.b > 0
                  ? $store.state.results[id].parameters.k1
                  : []
              "
            /> -->
          </td>
          <td>
            <font-awesome-icon
              v-on:click="goToParameterInput(id)"
              fixed-width
              size="sm"
              title="Refine method"
              v-bind:icon="['far', 'clone']"
            ></font-awesome-icon>

            <a
              style="margin-left: 10px;"
              title="Download as .RData"
              v-bind:href="makeDownloadUrl(id)"
              v-bind:download="id + '.RData'"
              ><font-awesome-icon
                fixed-width
                size="sm"
                v-bind:icon="['far', 'save']"
              ></font-awesome-icon
            ></a>
          </td>
        </tr>
      </tbody>
    </table>
    <button v-on:click="unselectAll()">Unselect all</button>
  </div>
</template>

<script lang="ts">
import { Vue, Prop, Component } from "vue-property-decorator";
import LagSet from "@/components/LagSet.vue";
import Histogram from "@/components/Histogram.vue";
import { mapGetters } from "vuex";
import VerticalWeight from "@/components/VerticalWeight.vue";
import { StoreState } from "../types/store";
import Tooltip from "@/components/Tooltip.vue";

class ResultTableClass extends Vue {
  public results!: string[];
  public resultColorsInclHighlight!: Record<string, string>;
}

@Component<ResultTableClass>({
  components: { Histogram, VerticalWeight, Tooltip, LagSet },
  computed: {
    ...mapGetters([
      "resultColorsInclHighlight",
      "results",
      "selectedResults",
      "selectedFailedResults",
      "selectedSuccessfulResults"
    ]),
    success() {
      const state = this.$store.state as StoreState;
      const successVals = this.results
        .filter(id => !!state.results[id] && !!state.results[id].parameters)
        .map(id => ({ id, success: state.results[id].parameters.success }))
        .reduce((agg, x) => ({ ...agg, [x.id]: x.success }), {});
      return successVals;
    },
    k1s() {
      const state = this.$store.state as StoreState;
      const k1s = this.results
        .filter(id => !!state.results[id] && !!state.results[id].parameters)
        .map(id => ({
          id,
          value: state.results[id].parameters.k1,
          b: state.results[id].parameters.b,
          color: this.resultColorsInclHighlight[id]
        }))
        .filter(r => r.b > 0)
        .map(r => ({ id: r.id, value: r.value, color: r.color }))
        .reduce((agg, x) => ({ ...agg, [x.id]: x }), {});
      return k1s;
    },
    k2s() {
      const state = this.$store.state as StoreState;
      return this.results
        .filter(id => !!state.results[id] && !!state.results[id].parameters)
        .map(id => ({
          id,
          value: state.results[id].parameters.k2,
          b: state.results[id].parameters.b,
          color: this.resultColorsInclHighlight[id]
        }))
        .filter(r => r.b < 1)
        .map(r => ({ id: r.id, value: r.value, color: r.color }))
        .reduce((agg, x) => ({ ...agg, [x.id]: x }), {});
    }
  }
})
export default class ResultTable extends ResultTableClass {
  makeDownloadUrl(resultId: string) {
    const apiUrl = process.env.VUE_APP_API_URL;
    return `${apiUrl}/gsobi/${resultId}/download`;
  }
  toggleResult(resultId: string) {
    this.$store.dispatch("toggleSelectedResult", resultId);
  }
  setHighlightedResult(result: string) {
    this.$store.dispatch("setHighlightedResult", result);
  }
  unsetHighlightedResult() {
    this.$store.dispatch("setHighlightedResult", "");
  }
  goToParameterInput(resultId: string) {
    this.$store.dispatch("initParameterInputWithResult", resultId);
    this.$router.push("/parameter-input");
  }
  unselectAll() {
    for (const res of this.$store.getters.selectedResults) {
      this.$store.dispatch("toggleSelectedResult", res);
    }
  }
}
</script>

<style lang="less" scoped>
.clickable {
  cursor: pointer;
}

table {
  td,
  th {
    padding: 5px 10px;
  }

  th {
    padding: 10px 10px;
    text-align: center;
  }
}
</style>
