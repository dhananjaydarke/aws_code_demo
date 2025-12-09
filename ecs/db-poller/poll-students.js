// ecs/db-poller/poll-students.js
const sql = require('mssql');

const config = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '1433', 10),
  database: process.env.DB_NAME,
  options: {
    encrypt: true,
    trustServerCertificate: true
  }
};

async function main() {
  try {
    console.log('Connecting to MSSQL...');
    await sql.connect(config);
    const result = await sql.query`SELECT TOP 10 * FROM dbo.Students`;
    console.log(`Fetched ${result.recordset.length} students:`);
    console.log(result.recordset);
  } catch (err) {
    console.error('DB poll error:', err);
    process.exit(1);
  } finally {
    await sql.close();
  }
}

main();
