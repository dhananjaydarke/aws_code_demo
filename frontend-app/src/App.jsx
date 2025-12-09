import React, { useEffect, useState } from "react";

function App() {
  const [students, setStudents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch("/api/students")
      .then((res) => {
        if (!res.ok) throw new Error("Failed to fetch students");
        return res.json();
      })
      .then((data) => {
        setStudents(data);
        setLoading(false);
      })
      .catch((err) => {
        console.error(err);
        setError(err.message);
        setLoading(false);
      });
  }, []);

  if (loading) return <div style={{ padding: "2rem" }}>Loading...</div>;
  if (error) return <div style={{ padding: "2rem" }}>Error: {error}</div>;

  return (
    <div style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>Students</h1>
      <table border="1" cellPadding="8" cellSpacing="0">
        <thead>
          <tr>
            <th>Roll No</th>
            <th>Name</th>
            <th>Grade</th>
            <th>Date of Birth</th>
          </tr>
        </thead>
        <tbody>
          {students.map((s) => (
            <tr key={s.RollNo || s.rollno || s.roll_no}>
              <td>{s.RollNo || s.rollno || s.roll_no}</td>
              <td>{s.Name || s.name}</td>
              <td>{s.Grade || s.grade}</td>
              <td>{new Date(s.DOB || s.dob).toLocaleDateString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default App;
