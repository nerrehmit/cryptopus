import ENV from "../config/environment";

export function initialize(/* application */) {
  if (ENV.environment !== "test") {
    /* eslint-disable no-undef  */
    $.getJSON({
      url: "/api/env_settings",
      async: false,
      success: function (envSettings) {
        ENV.sentryDsn = envSettings.sentry;
      }
    });
    /* eslint-enable no-undef  */
  }
}

export default {
  initialize
};
