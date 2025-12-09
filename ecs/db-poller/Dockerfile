FROM node:18-alpine
WORKDIR /app

COPY package*.json ./
RUN npm install --only=production

COPY poll-students.js ./

CMD ["npm", "start"]
