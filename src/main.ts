import Vue from "vue";
import App from "./App.vue";
import router from "./router";
import store from "./store";
import Tabs from "vue-nav-tabs/dist/vue-tabs.js";
import "vue-nav-tabs/themes/vue-tabs.css";
import { library } from "@fortawesome/fontawesome-svg-core";
import {
  faEye,
  faEyeSlash,
  faSave,
  faClone,
  faQuestionCircle
} from "@fortawesome/free-regular-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import draggable from "vuedraggable";
import VTooltip from "v-tooltip";

library.add(faEye);
library.add(faEyeSlash);
library.add(faQuestionCircle);
library.add(faSave);
library.add(faClone);

Vue.component("draggable", draggable);
Vue.component("font-awesome-icon", FontAwesomeIcon);

Vue.use(VTooltip);
Vue.use(Tabs);

Vue.config.productionTip = false;

new Vue({
  router,
  store,
  render: h => h(App)
}).$mount("#app");
