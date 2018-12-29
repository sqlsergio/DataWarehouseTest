USE PERSONDATABASE

/*********************
Hello! 

Please use the test data provided in the file 'PersonDatabase' to answer the following
questions. Please also import the dbo.Contacts flat file to a table for use. 

All answers should be written in SQL. 

***********************



QUESTION 1

The table dbo.Risk contains calculated risk scores for the population in dbo.Person. Write a 
query or group of queries that return the patient name, and their most recent risk level(s). 
Any patients that dont have a risk level should also be included in the results. 

**********************/

/*********************************** START ANSWER 1 ***********************************/
-- OPTION 1, USING RANK()/DENSE_RANK()
SELECT
	PersonName,
	ISNULL(AttributedPayer,'No Payer Info') AS AttributedPayer, -- Took the liberty to add default values for missing AttributedPayer...
	ISNULL(CAST(RiskLevel AS varchar(20)),'Undetermined') AS RiskLevel -- ...and RiskLevel
FROM (
	SELECT P.PersonName, AttributedPayer, RiskLevel, DENSE_RANK() OVER (PARTITION BY P.PersonName ORDER BY RiskDateTime DESC) AS RankLevel
	-- SELECT P.PersonName, AttributedPayer, RiskLevel, RANK() OVER (PARTITION BY P.PersonName ORDER BY RiskDateTime DESC) AS RankLevel
	FROM Person AS P
	LEFT JOIN Risk AS R
		ON P.PersonID = R.PersonID
	GROUP BY P.PersonName, RiskDateTime, R.AttributedPayer, R.RiskLevel
	) AS SZ
WHERE RankLevel = 1
ORDER BY 1,2;

-- OPTION 2, USING "SELF-JOINS" WITH MAX() FOR TABLE dbo.Risk
SELECT
	PersonName,
	ISNULL(AttributedPayer,'No Payer Info') AS AttributedPayer,
	ISNULL(CAST(RiskLevel AS varchar(20)),'Undetermined') AS RiskLevel
FROM Person AS P
LEFT JOIN (
	Risk AS R1
	INNER JOIN (
		SELECT PersonID, MAX(RiskDateTime) AS RiskDateTime
		FROM Risk
		GROUP BY PersonID
		) AS R2
		ON R1.PersonID = R2.PersonID
		AND R1.RiskDateTime = R2.RiskDateTime
	)
	ON P.PersonID = R1.PersonID
ORDER BY 1,2;
/************************************ END ANSWER 1 ************************************/



/**********************

QUESTION 2


The table dbo.Person contains basic demographic information. The source system users 
input nicknames as strings inside parenthesis. Write a query or group of queries to 
return the full name and nickname of each person. The nickname should contain only letters 
or be blank if no nickname exists.

**********************/

/*********************************** START ANSWER 2 ***********************************/
SELECT 
	PersonName AS OriginalPersonNameWithNickname,
	LTRIM(RTRIM(
		CASE
			WHEN CHARINDEX('(',PersonName) = 0 THEN PersonName 
			ELSE REPLACE(REPLACE(PersonName, SUBSTRING(PersonName, CHARINDEX('(',PersonName), LEN(PersonName) - CHARINDEX(')',REVERSE(PersonName)) + 1 - CHARINDEX('(',PersonName) + 1), ''), '  ',' ') 
		END
	)) AS PersonName, 
	LTRIM(RTRIM(
		CASE
			WHEN CHARINDEX('(',PersonName) = 0 THEN ''
			ELSE REPLACE(REPLACE(SUBSTRING(PersonName, CHARINDEX('(',PersonName), LEN(PersonName) - CHARINDEX(')',REVERSE(PersonName)) + 1 - CHARINDEX('(',PersonName) + 1),'(',''),')','') 
		END
	)) AS Nickname
FROM Person AS P;
/************************************ END ANSWER 2 ************************************/



/**********************

QUESTION 3

Building on the query in question 1, write a query that returns only one row per 
patient for the most recent levels. Return a level for a patient so that for patients with 
multiple levels Gold > Silver > Bronze


**********************/

/*********************************** START ANSWER 3 ***********************************/
-- OPTION 1 USING MULTIPLE SELF JOIN & NESTED SUB-QUERIES
SELECT 
	PersonName,
	CASE WHEN RiskLevelIndex = 1  THEN 'Gold' WHEN RiskLevelIndex = 2  THEN 'Silver' WHEN RiskLevelIndex = 3  THEN 'Bronze' ELSE 'Undetermined' END AS RiskLevelIndex
FROM (
	SELECT
		PersonName,
		MIN(CASE WHEN RiskLevel = 'Gold' THEN 1 WHEN RiskLevel = 'Silver' THEN 2 WHEN RiskLevel = 'Bronze' THEN 3 ELSE 4 END) AS RiskLevelIndex
	FROM Person AS P
	LEFT JOIN (
		Risk AS R1
		INNER JOIN (
			SELECT PersonID, MAX(RiskDateTime) AS RiskDateTime
			FROM Risk
			GROUP BY PersonID
			) AS R2
			ON R1.PersonID = R2.PersonID
			AND R1.RiskDateTime = R2.RiskDateTime
		)
		ON P.PersonID = R1.PersonID
	GROUP BY PersonName
	) AS SZ
ORDER BY 1;

-- OPTION 2, USING A CTE
WITH IndexedRiskLevel(PersonName,RiskLevelIndex) AS (
	SELECT
		PersonName,
		MIN(CASE WHEN RiskLevel = 'Gold' THEN 1 WHEN RiskLevel = 'Silver' THEN 2 WHEN RiskLevel = 'Bronze' THEN 3 ELSE 4 END) AS RiskLevelIndex
	FROM Person AS P
	LEFT JOIN (
		Risk AS R1
		INNER JOIN (
			SELECT PersonID, MAX(RiskDateTime) AS RiskDateTime
			FROM Risk
			GROUP BY PersonID
			) AS R2
			ON R1.PersonID = R2.PersonID
			AND R1.RiskDateTime = R2.RiskDateTime
		)
		ON P.PersonID = R1.PersonID
	GROUP BY PersonName
	)
SELECT 
	PersonName,
	CASE WHEN RiskLevelIndex = 1  THEN 'Gold' WHEN RiskLevelIndex = 2  THEN 'Silver' WHEN RiskLevelIndex = 3  THEN 'Bronze' ELSE 'Undetermined' END AS RiskLevelIndex
FROM IndexedRiskLevel
ORDER BY 1;
/************************************ END ANSWER 3 ************************************/



/**********************

QUESTION 4

The following query returns patients older than 55 and their assigned risk level history. 

A. What changes could be made to this query to improve optimization? Rewrite the query with  
any improvements in the Answer A section below.

B. What changes would we need to make to run this query at any time to return patients over 55?
Rewrite the query with any required changes in Answer B section below. 

**********************/


	SELECT *
	FROM DBO.Person P
	INNER JOIN DBO.Risk R
		ON R.PersonID = P.PersonID

	WHERE P.PersonID IN 
		(
			SELECT personid
			FROM Person
			WHERE DATEOFBIRTH < '1/1/1961'
		)

	AND P.ISACTIVE = '1'



--------Answer A--------------------

/*********************************** START ANSWER 4 ***********************************/
/*********************
NOTE: 
	No changes made to the above query improved the execution plan on my machine due to the small amount of data. 
	Below, I provide two options that, in combination with proper indexing, should render better performance for larger Data Sets.
*********************/
-- OPTION 1, USING "EXISTS" INSTEAD OF "IN"
SELECT *
FROM DBO.Person AS P
INNER JOIN DBO.Risk AS R
	ON R.PersonID = P.PersonID
WHERE EXISTS (
	SELECT 1
	FROM Person AS P2
	WHERE P.PersonID = P2.PersonID
	AND P2.DATEOFBIRTH < '1/1/1961'
	AND P2.ISACTIVE = '1'
	);

-- OPTION 2, REMOVING SUBQUERY ALTOGETHER
SELECT *
FROM DBO.Person AS P
INNER JOIN DBO.Risk AS R
	ON R.PersonID = P.PersonID
WHERE P.DATEOFBIRTH < '1/1/1961'
AND P.ISACTIVE = '1';


---------Answer B--------------------

-- OPTION 1, USING "EXISTS" INSTEAD OF "IN"
SELECT *
FROM DBO.Person AS P
INNER JOIN DBO.Risk AS R
	ON R.PersonID = P.PersonID
WHERE EXISTS (
	SELECT 1
	FROM Person AS P2
	WHERE P.PersonID = P2.PersonID
	AND P2.DATEOFBIRTH < CAST(DATEADD(YEAR, -55, GETDATE()) AS date)
	AND P2.ISACTIVE = '1'
	);

-- OPTION 2, REMOVING SUBQUERY ALTOGETHER
SELECT *
FROM DBO.Person AS P
INNER JOIN DBO.Risk AS R
	ON R.PersonID = P.PersonID
WHERE P.DATEOFBIRTH < CAST(DATEADD(YEAR, -55, GETDATE()) AS date)
AND P.ISACTIVE = '1';
/************************************ END ANSWER 4 ************************************/



/**********************

QUESTION 5

Create a patient matching stored procedure that accepts (first name, last name, dob and sex) as parameters and 
and calculates a match score from the Person table based on the parameters given. If the parameters do not match the existing 
data exactly, create a partial match check using the weights below to assign partial credit for each. Return PatientIDs and the
 calculated match score. Feel free to modify or create any objects necessary in PersonDatabase.  

FirstName 
	Full Credit = 1
	Partial Credit = .5

LastName 
	Full Credit = .8
	Partial Credit = .4

Dob 
	Full Credit = .75
	Partial Credit = .3

Sex 
	Full Credit = .6
	Partial Credit = .25


**********************/

/*********************************** START ANSWER 5 ***********************************/
USE [PersonDatabase]
GO

-- For the sproc below to work the following statments need to be run first
/*
	ALTER TABLE dbo.Person ADD FirstName varchar(255);
	ALTER TABLE dbo.Person ADD LastName varchar(255);
	
	UPDATE dbo.Person SET FirstName = 'Azra', LastName = 'Magnus' WHERE PersonID = 1;
	UPDATE dbo.Person SET FirstName = 'Palmer', LastName = 'Hales' WHERE PersonID = 2;
	UPDATE dbo.Person SET FirstName = 'Lilla', LastName = 'Solano' WHERE PersonID = 3;
	UPDATE dbo.Person SET FirstName = 'Romeo', LastName = 'Styles' WHERE PersonID = 4;
	UPDATE dbo.Person SET FirstName = 'Margot', LastName = 'Steed' WHERE PersonID = 5;
*/

DROP PROCEDURE IF EXISTS dbo.usp_Fuzzy_Person_Matching;
GO

CREATE PROCEDURE dbo.usp_Fuzzy_Person_Matching(
	@FirstName varchar(255),
	@LastName varchar(255),
	@DOB datetime,
	@Sex varchar(10)
)
AS
BEGIN
	SELECT PersonID, 
		CASE WHEN FirstName = @FirstName THEN 1 WHEN FirstName LIKE '%' + @FirstName + '%' THEN .5 ELSE 0 END +
		CASE WHEN LastName = @LastName THEN .8 WHEN LastName LIKE '%' + @LastName + '%' THEN .4 ELSE 0 END +
		CASE WHEN CAST(DateofBirth AS date) = CAST(@DOB AS date) THEN .75 WHEN YEAR(DateofBirth) = YEAR(@DOB) OR MONTH(DateofBirth) = MONTH(@DOB) OR DAY(DateofBirth) = DAY(@DOB) THEN .3 ELSE 0 END +
		CASE WHEN Sex = @Sex THEN .6 WHEN Sex LIKE '%' + @Sex + '%' THEN .25 ELSE 0 END AS MatchScore
	FROM dbo.Person;
END;
GO
/************************************ END ANSWER 5 ************************************/



/**********************

QUESTION 6

A. Looking at the script 'PersonDatabase', what change(s) to the tables could be made to improve the database structure?  

B. What method(s) could we use to standardize the data allowed in dbo.Person (Sex) to only allow 'Male' or 'Female'?

C. Assuming these tables will grow very large, what other database tools/objects could we use to ensure they remain
efficient when queried?


**********************/
/*********************************** START ANSWER 6 ***********************************/
-- A.
CREATE TABLE dbo.Person
(
	PersonID INT PRIMARY KEY -- Add PK on PersonID (Maybe IDENTITY(1,1) as well)
	, PersonName VARCHAR(255)
	, Sex VARCHAR(10) 
	, DateofBirth DATETIME
	, Address VARCHAR(255)
	, IsActive INT
);
GO

CREATE TABLE dbo.Risk
(
	PersonID INT -- Change varchar(10) to INT to match Data Type of referenced table.
	, AttributedPayer VARCHAR(255)
	, RiskScore DECIMAL(10,6)
	, RiskLevel VARCHAR(10)
	, RiskDateTime DATETIME
	, FOREIGN KEY (PersonID) REFERENCES dbo.Person(PersonID) -- And add FK to dbo.Person.PersonID (assuming PK was added)
)
GO


-- B.
CREATE TABLE dbo.Person
(
	PersonID INT PRIMARY KEY --
	, PersonName VARCHAR(255)
	, Sex VARCHAR(10) 
	, DateofBirth DATETIME
	, Address VARCHAR(255)
	, IsActive INT
	, CONSTRAINT CC_SEX CHECK (Sex IN ('Female', 'Male')) -- Add Check constraint that restricts Sex values to 'Female' or 'Male'.
);
GO


-- C.
-- In ADDITION TO THE ABOVE CHANGES I would add some indexes like the ones below, but the decision to do so will depend on workload and query performance.
-- Add indexes to the dbo.Risk table
CREATE INDEX IX_Risk_RiskDateTime ON dbo.Risk(RiskDateTime)
GO
CREATE INDEX IX_Risk_PersonID ON dbo.Risk(PersonID)
GO

-- Add index to the dbo.Risk table
CREATE INDEX IX_Person_PersonName ON dbo.Person(PersonName)
GO

-- I would also make some design changes, like moving the Address field to it's own table and breaking each part of the date into it's own field.
-- The new dbo.Person and dbo.PersonAddress tables would look somehting like this:
CREATE TABLE dbo.Person
(
	PersonID BIGINT IDENTITY(1,1) PRIMARY KEY NOT NULL
	, PersonName VARCHAR(255)
	, Sex VARCHAR(10) 
	, DateofBirth DATETIME
	, IsActive INT
);
GO

-- The below table assumes only US addresses will be added:
CREATE TABLE dbo.PersonAddress (
	PersonAddressID BIGINT IDENTITY(1,1) PRIMARY KEY NOT NULL
	, PersonID BIGINT
	, AddressLine1 VARCHAR(255)
	, AddressLine2 VARCHAR(255)
	, AddressState VARCHAR(2)
	, AddressZIP VARCHAR(10)
	, IsActive INT
	, FOREIGN KEY (PersonID) REFERENCES dbo.Person(PersonID)
	);
GO

-- Finally, PARITIONING:
-- We can partition the dbo.Person & dbo.Risk tables by range on a new computed column based on PersonID, 
-- so joins between the dbo.Person and the dbo.Risk tables will happen on the same partition.
-- The example below shows the creation of a new dbo.PersonPartition table with only 4 partitions.
-- For production, an analysis should be done to determine the more appropriate number of partitions.
-- This is not the only way to partition the table. We could instead use the PersonID value itself.
-- The problem wiht this is that you will need to add new partitions as the data grows. 
-- Also, depending on how the data grows and becomes stale, the more recent partitions will be the most active ones, 
-- which will cause hotspots as most of the queries will be accessing it, taking away the advantages of partitioning.
USE PersonDatabase
GO
ALTER DATABASE PersonDatabase ADD FILEGROUP Part0FG;
GO
ALTER DATABASE PersonDatabase ADD FILEGROUP Part1FG;
GO
ALTER DATABASE PersonDatabase ADD FILEGROUP Part2FG;
GO
ALTER DATABASE PersonDatabase ADD FILEGROUP Part3FG;
GO
-- For simplicity, all data files in this example will be created on a single drive. 
-- Ideally, The data files should be created on separate volumes to avoid disk contention and reduce I/O waits
ALTER DATABASE PersonDatabase ADD FILE (  
	NAME = Partition0data0,
	FILENAME = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER2016\MSSQL\DATA\F0dat0.ndf',
	SIZE = 5MB,
	MAXSIZE = 100MB,
	FILEGROWTH = 5MB
	)
TO FILEGROUP Part0FG; 
GO
ALTER DATABASE PersonDatabase ADD FILE (  
	NAME = Partition1data1,
	FILENAME = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER2016\MSSQL\DATA\F1dat1.ndf',
	SIZE = 5MB,
	MAXSIZE = 100MB,
	FILEGROWTH = 5MB
	)
TO FILEGROUP Part1FG; 
GO
ALTER DATABASE PersonDatabase ADD FILE (  
	NAME = Partition2data2,
	FILENAME = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER2016\MSSQL\DATA\F2dat2.ndf',
	SIZE = 5MB,
	MAXSIZE = 100MB,
	FILEGROWTH = 5MB
	)
TO FILEGROUP Part2FG; 
GO
ALTER DATABASE PersonDatabase ADD FILE (  
	NAME = Partition3data3,
	FILENAME = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER2016\MSSQL\DATA\F3dat3.ndf',
	SIZE = 5MB,
	MAXSIZE = 100MB,
	FILEGROWTH = 5MB
	)
TO FILEGROUP Part3FG; 
GO
CREATE PARTITION FUNCTION PartRanges (int) AS
	RANGE LEFT FOR VALUES (0, 1, 2);
GO  
CREATE PARTITION SCHEME PartRanges AS
	PARTITION PartRanges TO (Part0FG, Part1FG, Part2FG, Part3FG);
GO
DROP TABLE IF EXISTS dbo.PersonPartition;
GO
CREATE TABLE dbo.PersonPartition (
	PersonID BIGINT IDENTITY(1,1) NOT NULL
	, PersonName VARCHAR(255)
	, Sex VARCHAR(10) 
	, DateofBirth DATETIME
	, IsActive INT
	, PartitioKey AS CAST(PersonID%4 AS INT) PERSISTED
	, PRIMARY KEY (PersonID,PartitioKey)
	)
ON PartRanges (PartitioKey);
GO
CREATE INDEX IX_PersonPartition_PartitioKey ON dbo.PersonPartition(PartitioKey);
GO
INSERT INTO dbo.PersonPartition (PersonName, Sex, DateofBirth, IsActive)
VALUES 
	('Azra (Az) Magnus', 'Male','1997-07-24', 1),
	('Palmer Hales (Billy)', 'Male','1951-07-21', 1),
	('(Lilly) Lilla Solano', 'F','1982-05-17', 1),
	('Romeo Styles', 'Male','1949-06-02', 1),
	('Margot Steed ())', 'Female','1962-03-12', 1);
GO
-- Check the data just added to the new table
SELECT *
FROM dbo.PersonPartition;
-- Check the data just added to the new table
SELECT partition_id, object_id, index_id, partition_number, row_count
FROM sys.dm_db_partition_stats
WHERE object_id = OBJECT_ID('dbo.PersonPartition')
AND index_id < 2;
/************************************ END ANSWER 6 ************************************/



/**********************

QUESTION 7

Write a query to return risk data for all patients, all contracts 
and a moving average of risk for that patient and contract in dbo.Risk. 

**********************/

/*********************************** START ANSWER 7 ***********************************/
SELECT P.PersonName, R.AttributedPayer, R.RiskDateTime, R.RiskScore,
	AVG(R.RiskScore) OVER(PARTITION BY P.PersonName, R.AttributedPayer ORDER BY R.RiskDateTime ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS MovingAverage
FROM Person AS P
LEFT JOIN Risk AS R
	ON P.PersonID = R.PersonID
GROUP BY P.PersonName, R.AttributedPayer, R.RiskDateTime, R.RiskScore
ORDER BY P.PersonName, R.AttributedPayer, R.RiskDateTime;



/**********************

QUESTION 8

Write script to load the dbo.Dates table with all applicable data elements for dates 
between 1/1/2010 and 50 days past the current date.


**********************/
/*********************************** START ANSWER 8 ***********************************/
SET NOCOUNT ON;
GO

DECLARE @DaysIntoTheFuture int = 50;
DECLARE @StartDate date = CAST('1/1/2010' AS date);
DECLARE @EndDate date = CAST(DATEADD(DAY, @DaysIntoTheFuture, GETDATE()) AS DATE);

SELECT @StartDate = ISNULL(MAX(DATEADD(DAY,1,DateValue)),@StartDate)
FROM dbo.Dates;

WHILE @StartDate <= @EndDate
BEGIN
	INSERT INTO dbo.Dates(
		DateValue,
		DateDayofMonth,
		DateDayofYear,
		DateQuarter,
		DateWeekdayName,
		DateMonthName,
		DateYearMonth
		)
	SELECT 
		@StartDate AS DateValue,
		DAY(@StartDate) AS DateDayofMonth,
		DATEPART(DAYOFYEAR,@StartDate) AS DateDayofYear,
		DATEPART(QUARTER,@StartDate) AS DateQuarter,
		DATENAME(WEEKDAY,@StartDate) AS DateWeekdayName,
		DATENAME(MONTH,@StartDate)  AS DateMonthName,
		CAST(YEAR(@StartDate) * 100 + MONTH(@STARTDATE) AS varchar(6)) AS DateYearMonth;

	SET @StartDate = DATEADD(DAY,1,@StartDate);
END;
GO

SET NOCOUNT OFF;
GO
/************************************ END ANSWER 8 ************************************/



/**********************

QUESTION 9

Please import the data from the flat file dbo.Contracts.txt to a table to complete this question. 

Using the data in dbo.Contracts, create a query that returns 

(PersonID, AttributionStartDate, AttributionEndDate) 

merging contiguous date ranges into one row and returning a new row when a break in time exists. 
The date at the beginning of the rage can be the first day of that month, the day of the end of the range can
be the last day of that month. Use the dbo.Dates table if helpful.

**********************/

/*********************************** START ANSWER 9 ***********************************/
/*	ASSUMPTION: For the two answers below, variable @DaysIntoTheFuture from answer script to QUESTION 8, was set to 730.	*/
-- INTERPRETATION 1: A record is going to be return for every period of uninterrupted attribution, covering multiple months if aplicable
WITH ContractsRanges (PersonID, DateValue) AS (
	SELECT
		C1.PersonID,
		D1.DateValue
	FROM dbo.Contracts AS C1
	INNER JOIN dbo.Dates AS D1
		ON D1.DateValue BETWEEN C1.ContractStartDate AND C1.ContractEndDate
	GROUP BY C1.PersonID, D1.DateValue
	)
SELECT 
	PersonID,
	AttributionStartDate,
	MAX(AttributionEndDate) AS AttributionEndDate
FROM (
	SELECT 
		CR1.PersonID,
		MAX(CASE WHEN CR2.DateValue IS NULL THEN CR1.DateValue END) 
			OVER(PARTITION BY CR1.PersonID ORDER BY CR1.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS AttributionStartDate, 
		/*	For this to work table dbo.Dates has to go beyond the MAX ContractEndDate in the dbo.Contracts.txt file, 
			otherwise the dates will stop 50 days into the future	*/
		MAX(CASE WHEN CR3.DateValue IS NULL THEN CR1.DateValue END) 
			OVER(PARTITION BY CR1.PersonID ORDER BY CR1.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS AttributionEndDate
	FROM ContractsRanges AS CR1
	LEFT JOIN ContractsRanges AS CR2
		ON CR1.PersonID = CR2.PersonID
		AND CR1.DateValue = DATEADD(DAY, 1, CR2.DateValue)
	LEFT JOIN ContractsRanges AS CR3
		ON CR1.PersonID = CR3.PersonID
		AND CR1.DateValue = DATEADD(DAY, -1, CR3.DateValue)
	) AS SZ1
GROUP BY PersonID, AttributionStartDate
ORDER BY 1,2;


-- Interpretation 2: A record is going to be return for every period of uninterrupted attribution, from the start of attribution to the end of the month, 
-- then one record will be returned for each following whole month until a break in attribution is found, or the last day of attribution is encountered.
WITH ContractsRanges (PersonID, DateValue) AS (
	SELECT
		C1.PersonID,
		D1.DateValue
	FROM dbo.Contracts AS C1
	INNER JOIN dbo.Dates AS D1
		ON D1.DateValue BETWEEN C1.ContractStartDate AND C1.ContractEndDate
	GROUP BY C1.PersonID, D1.DateValue
	)
SELECT 
	PersonID,
	AttributionStartDate,
	MAX(AttributionEndDate) AS AttributionEndDate
FROM (
	SELECT 
		CR1.PersonID,
		MAX(CASE WHEN CR2.DateValue IS NULL OR DAY(CR1.DateValue) = 1 THEN CR1.DateValue END) 
			OVER(PARTITION BY CR1.PersonID ORDER BY CR1.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS AttributionStartDate, 
		/*	For this to work table dbo.Dates has to go beyond the MAX ContractEndDate in the dbo.Contracts.txt file, 
			otherwise the dates will stop 50 days into the future	*/
		MAX(CASE WHEN CR3.DateValue IS NULL OR DAY(CR3.DateValue) = 1 THEN CR1.DateValue END) 
			OVER(PARTITION BY CR1.PersonID ORDER BY CR1.DateValue ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS AttributionEndDate
	FROM ContractsRanges AS CR1
	LEFT JOIN ContractsRanges AS CR2
		ON CR1.PersonID = CR2.PersonID
		AND CR1.DateValue = DATEADD(DAY, 1, CR2.DateValue)
	LEFT JOIN ContractsRanges AS CR3
		ON CR1.PersonID = CR3.PersonID
		AND CR1.DateValue = DATEADD(DAY, -1, CR3.DateValue)
	) AS SZ1
GROUP BY PersonID, AttributionStartDate
ORDER BY 1,2;
/************************************ END ANSWER 9 ************************************/
