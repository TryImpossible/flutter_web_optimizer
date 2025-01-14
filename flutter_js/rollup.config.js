import { terser } from "rollup-plugin-terser";

export default {
  input: "src/flutter.js", // 项目入口文件
  output: {
    file: "dist/flutter.js", // 输出文件
    format: "iife", // 立即执行函数形式，适合浏览器
    sourcemap: true, // 启用 Source Map
  },
  plugins: [terser()], // 使用 Terser 压缩混淆代码
};
