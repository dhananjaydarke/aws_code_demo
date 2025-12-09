# Students SPA Frontend

React SPA that calls `/api/students` to display all students.

Build:

```bash
npm install
npm run build
```

Then upload contents of `dist/` to the S3 bucket created by the `spa` Terraform repo:

```bash
aws s3 sync dist/ s3://students.dhananjayglobaluniversity.com/
```
