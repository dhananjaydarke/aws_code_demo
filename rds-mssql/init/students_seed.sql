IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Students')
BEGIN
    CREATE TABLE Students (
        RollNo INT PRIMARY KEY,
        Name NVARCHAR(100) NOT NULL,
        Grade NVARCHAR(2) NOT NULL,
        DOB DATE NOT NULL
    );
END;

IF NOT EXISTS (SELECT * FROM Students)
BEGIN
    INSERT INTO Students (RollNo, Name, Grade, DOB) VALUES
    (1, 'Aarav Sharma', 'A', '2008-01-15'),
    (2, 'Sneha Patil', 'B', '2008-03-22'),
    (3, 'Rohit Kulkarni', 'A', '2007-11-30'),
    (4, 'Priya Deshmukh', 'C', '2008-07-09'),
    (5, 'Vikram Joshi', 'B', '2008-05-17'),
    (6, 'Neha Kamat', 'A', '2007-12-25'),
    (7, 'Sahil Pawar', 'B', '2008-02-11'),
    (8, 'Tanvi Dixit', 'A', '2007-10-02'),
    (9, 'Aditya Gokhale', 'C', '2008-04-14'),
    (10, 'Kiran Sawant', 'B', '2008-06-27');
END;
