const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
  entry: './src/index.jsx',

  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'bundle.js',
    publicPath: '/',         // IMPORTANT for SPA routing
    clean: true
  },

  resolve: {
    extensions: ['.js', '.jsx'],
  },

  module: {
    rules: [
      {
        test: /\.(js|jsx)$/,
        exclude: /node_modules/,
        use: 'babel-loader'
      },
      {
        test: /\.css$/,
        use: ['style-loader','css-loader']
      },
    ],
  },

  plugins: [
    new HtmlWebpackPlugin({
      template: './public/index.html',   // Source index.html
      filename: 'index.html'             // Output to dist/
    })
  ],

  devServer: {
    historyApiFallback: true,
  }
};
