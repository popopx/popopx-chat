import {defineConfig} from "vitest/config"
import path from "path"

export default defineConfig({
  test: {
    globals: true,
    testTimeout: 10000,
    // Clear backend signals — .npmrc next to package.json otherwise injects
    // npm_config_popopx_backend into every test's env, breaking sqlite-default
    // assumptions in parseConfig tests.
    env: {
      POPOPX_BACKEND: "",
      npm_config_popopx_backend: "",
    },
  },
  resolve: {
    alias: {
      "popopx-chat": path.resolve(__dirname, "test/__mocks__/popopx-chat.js"),
      "@popopx-chat/types": path.resolve(__dirname, "test/__mocks__/popopx-chat-types.js"),
    },
  },
})
