<template>
  <div>
    <select id="sourceselector" v-model="source">
      <option disabled value="">Please select a source</option>
      <option v-bind:key="source" v-for="source in sources">{{
        source
      }}</option>
    </select>
  </div>
</template>

<script lang="ts">
import { Component, Prop, Vue } from "vue-property-decorator";

@Component({
  watch: {
    source: function(newSource, oldSource) {
      this.$emit("source-changed", newSource);
    }
  },
  data: function() {
    return {
      source: this.$props.initialSource
    };
  },
  computed: {
    sources() {
      return this.$store.state.colnames;
    }
  }
})
export default class SourceSelector extends Vue {
  @Prop() private initialSource!: string;
}
</script>
