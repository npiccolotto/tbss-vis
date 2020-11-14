<template>
  <div id="app">
    <div class="loader-container" v-show="numInflightRequests > 0">
      <div class="loader"></div>
    </div>

    <div v-if="initialized">
      <router-view />
    </div>
    <div v-if="!initialized">
      Please wait while data is loaded
    </div>
  </div>
</template>

<script lang="ts">
import { Vue, Component } from "vue-property-decorator";
@Component({
  computed: {
    numInflightRequests() {
      return this.$store.state.numInflightRequests;
    },
    initialized() {
      return this.$store.getters.initialized;
    }
  }
})
export default class App extends Vue {
  async mounted() {
    await this.$store.dispatch("fetchInitialGuidanceValues");
    await this.$store.dispatch("fetchLagsToCalendar");
    this.$store.dispatch("fetchAutocorrelationGuidance");
    this.$store.dispatch("fetchEigenvalueGuidance");
    this.$store.dispatch("fetchCalendarProximities");
    await this.$store.dispatch("fetchColumnNames");
    for (const colname of this.$store.state.colnames) {
      this.$store.dispatch("fetchColumn", colname);
    }
    this.$store.dispatch("fetchInitialData");

    this.$router.push("/data-load");
  }
}
</script>

<style lang="less">
#app {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  margin: 5px;
}

input,
textarea,
select,
fieldset {
  margin-bottom: 0;
}

button,
.button,
input[type="submit"],
input[type="reset"],
input[type="button"] {
  margin: 0rem;
  &.small {
    padding: 0 15px;
    line-height: 25px;
    height: 25px;
    font-size: 8px;
  }

  &[disabled] {
    background-color: #eee;
    color: #888;
    pointer-events: none;
  }
}

input[type="range"],
input[type="number"],
select {
  &.small {
    padding: 0 15px;
    line-height: 25px;
    height: 25px;
  }
}

.input-label {
  font-size: 10px;
  margin-bottom: 5px;
  user-select: none;
}

label {
  font-weight: normal;
  user-select: none;
}

.loader-container {
  position: absolute;
  top: 10px;
  right: 3rem;
}

.loader,
.loader:before,
.loader:after {
  border-radius: 50%;
  width: 2.5em;
  height: 2.5em;
  -webkit-animation-fill-mode: both;
  animation-fill-mode: both;
  -webkit-animation: load7 1.8s infinite ease-in-out;
  animation: load7 1.8s infinite ease-in-out;
}
.loader,
.loader:before,
.loader:after {
  border-radius: 50%;
  width: 1rem;
  height: 1rem;
  -webkit-animation-fill-mode: both;
  animation-fill-mode: both;
  -webkit-animation: load7 1.8s infinite ease-in-out;
  animation: load7 1.8s infinite ease-in-out;
}
.loader {
  color: #555;
  font-size: 10px;
  position: relative;
  text-indent: -9999em;
  -webkit-transform: translateZ(0);
  -ms-transform: translateZ(0);
  transform: translateZ(0);
  -webkit-animation-delay: -0.16s;
  animation-delay: -0.16s;
}
.loader:before,
.loader:after {
  content: "";
  position: absolute;
  top: 0;
}
.loader:before {
  left: -1.5rem;
  -webkit-animation-delay: -0.32s;
  animation-delay: -0.32s;
}
.loader:after {
  left: 1.5rem;
}
@-webkit-keyframes load7 {
  0%,
  80%,
  100% {
    box-shadow: 0 1rem 0 -1.3rem;
  }
  40% {
    box-shadow: 0 1rem 0 0;
  }
}
@keyframes load7 {
  0%,
  80%,
  100% {
    box-shadow: 0 1rem 0 -1.3rem;
  }
  40% {
    box-shadow: 0 1rem 0 0;
  }
}
.tooltip {
  display: block !important;
  z-index: 10000;
}

.tooltip .tooltip-inner {
  background: black;
  color: white;
  border-radius: 16px;
  padding: 5px 10px 4px;
}

.tooltip .tooltip-arrow {
  width: 0;
  height: 0;
  border-style: solid;
  position: absolute;
  margin: 5px;
  border-color: black;
  z-index: 1;
}

.tooltip[x-placement^="top"] {
  margin-bottom: 5px;
}

.tooltip[x-placement^="top"] .tooltip-arrow {
  border-width: 5px 5px 0 5px;
  border-left-color: transparent !important;
  border-right-color: transparent !important;
  border-bottom-color: transparent !important;
  bottom: -5px;
  left: calc(50% - 5px);
  margin-top: 0;
  margin-bottom: 0;
}

.tooltip[x-placement^="bottom"] {
  margin-top: 5px;
}

.tooltip[x-placement^="bottom"] .tooltip-arrow {
  border-width: 0 5px 5px 5px;
  border-left-color: transparent !important;
  border-right-color: transparent !important;
  border-top-color: transparent !important;
  top: -5px;
  left: calc(50% - 5px);
  margin-top: 0;
  margin-bottom: 0;
}

.tooltip[x-placement^="right"] {
  margin-left: 5px;
}

.tooltip[x-placement^="right"] .tooltip-arrow {
  border-width: 5px 5px 5px 0;
  border-left-color: transparent !important;
  border-top-color: transparent !important;
  border-bottom-color: transparent !important;
  left: -5px;
  top: calc(50% - 5px);
  margin-left: 0;
  margin-right: 0;
}

.tooltip[x-placement^="left"] {
  margin-right: 5px;
}

.tooltip[x-placement^="left"] .tooltip-arrow {
  border-width: 5px 0 5px 5px;
  border-top-color: transparent !important;
  border-right-color: transparent !important;
  border-bottom-color: transparent !important;
  right: -5px;
  top: calc(50% - 5px);
  margin-left: 0;
  margin-right: 0;
}

.tooltip.popover .popover-inner {
  background: #f9f9f9;
  color: black;
  padding: 24px;
  border-radius: 5px;
  box-shadow: 0 5px 30px rgba(black, 0.1);
}

.tooltip.popover .popover-arrow {
  border-color: #f9f9f9;
}

.tooltip[aria-hidden="true"] {
  visibility: hidden;
  opacity: 0;
  transition: opacity 0.15s, visibility 0.15s;
}

.tooltip[aria-hidden="false"] {
  visibility: visible;
  opacity: 1;
  transition: opacity 0.15s;
}

.svg-inline--fa {
  color: #666;
  cursor: pointer;
  &:hover {
    color: black;
  }
}
</style>
