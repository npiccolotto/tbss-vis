<template>
  <div>
    <GlobalControls firstScreen="true" />
    <div
      v-bind:class="{
        'data-load__container': true,
        'data-load__container--with-lag-input': showLagInput
      }"
    >
      <div class="data-load__timeseries">
        <h5>
          Input Time Series
        </h5>
        <p>
          Brush to zoom into a smaller time frame, double left click to reset
          this zoom. Hold shift and click left to enlarge Y axis, right click to
          reset to small size.
        </p>
        <TimeSeries
          v-bind:key="colname"
          v-for="colname in $store.state.colnames"
          v-bind:tsdata="[
            {
              value: $store.state.sources.raw[colname],
              color: 'black'
            }
          ]"
          v-bind:height="50"
          v-bind:width="showLagInput ? 350 : 600"
          v-bind:title="colname"
        />
      </div>
      <div class="data-load__acf">
        <h5>
          Select Lag Boundary
        </h5>

        <LagInput
          v-if="showLagInput"
          v-bind:selectedLags="selectedLags"
          v-on:select-lag="handleLagSelect"
          v-bind:numLagsToSelect="1"
        />
        <div v-else>
          <p>
            For better computation performance and visual accuracy, all
            computations and visualizations will only consider lags up to
            <code>{{ $store.state.maximumLag }}</code
            >, the current <em>lag boundary</em>. You can select a smaller
            boundary by clicking 'Select smaller boundary', or reset it to the
            default of <code>{{ defaultMaxLag }}</code> by clicking 'Reset to
            default'.
          </p>
          <div style="margin-bottom: 20px;">
            <button class="small" v-on:click="showLagInput = true">
              Select smaller boundary
            </button>
            <button
              class="small"
              v-bind:disabled="defaultMaxLag === $store.state.maximumLag"
              v-on:click="resetMaximumLag"
            >
              Reset to default
            </button>
          </div>
        </div>
        <span v-if="showLagInput"
          >Selected Lag Boundary: {{ selectedLags[0] }}</span
        >
        <button
          class="button"
          v-bind:disabled="selectedLags.length === 0"
          v-on:click="applyMaximumLag"
        >
          ✓ Proceed
        </button>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import TimeSeries from "@/components/TimeSeries.vue";
import AutocorrelationFunction from "@/components/acf/AutocorrelationFunction.vue";
import { Component, Prop, Vue } from "vue-property-decorator";
import LagInput from "@/components/parameter-input/LagInput.vue";
import SourceSelector from "@/components/SourceSelector.vue";
import { StoreState } from "../types/store";
import Tooltip from "@/components/Tooltip.vue";
import GlobalControls from "@/components/GlobalControls.vue";

@Component({
  components: {
    TimeSeries,
    Tooltip,
    GlobalControls,
    SourceSelector,
    LagInput,
    AutocorrelationFunction
  },
  computed: {
    defaultMaxLag: function() {
      const state = this.$store.state as StoreState;
      if (state.sources.n > 0) {
        return state.sources.n - Math.floor(state.sources.n / 4);
      }
      return "[calculating]";
    }
  },
  data: function() {
    return {
      showLagInput: false,
      selectedLags: [this.$store.state.maximumLag]
    };
  }
})
export default class DataLoad extends Vue {
  applyMaximumLag() {
    this.$store.dispatch("applyMaximumLag", this.$data.selectedLags[0]);
    this.$router.push("/");
  }

  handleLagSelect(lags: number[]) {
    this.$data.selectedLags = lags;
  }

  resetMaximumLag() {
    this.$store.dispatch("resetMaximumLag");
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped lang="less">
.data-load__container {
  grid-gap: 30px;
  display: grid;
  grid-template-columns: 600px 600px;

  &--with-lag-input {
    grid-template-columns: 350px auto;
  }
}
</style>
