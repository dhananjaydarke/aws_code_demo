IF DB_ID('StudentsDB') IS NULL
BEGIN
    CREATE DATABASE StudentsDB;
END;
GO

USE StudentsDB;
GO

IF OBJECT_ID('dbo.Students', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Students (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(100) NOT NULL,
        RollNo INT NOT NULL UNIQUE,
        Grade NVARCHAR(5) NOT NULL,
        DOB DATE NOT NULL
    );
END;
GO

DELETE FROM dbo.Students;
GO

INSERT INTO dbo.Students (Name, RollNo, Grade, DOB) VALUES
('Alice Johnson',      101, 'A',  '2007-03-15'),
('Brian Smith',        102, 'B+', '2006-11-02'),
('Catherine Lee',      103, 'A-', '2007-07-21'),
('David Patel',        104, 'B',  '2006-01-30'),
('Emily Davis',        105, 'A',  '2007-09-12'),
('Franklin Rodriguez', 106, 'C+', '2005-12-05'),
('Grace Kim',          107, 'B-', '2006-05-19'),
('Henry Wilson',       108, 'A+', '2007-02-08'),
('Isha Kapoor',        109, 'B+', '2006-08-25'),
('Jacob Nguyen',       110, 'A-', '2007-10-03');
GO
