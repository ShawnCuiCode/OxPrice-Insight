COMP6037：数据分析基础课程

课程作业 1：2024-25学年第1学期

工程、计算与数学学院
牛津布鲁克斯大学

简介

这是一次个人作业，因此每位学生需要独立完成提交。

本作业占模块总成绩的 40%。

在此作业中，您将使用从不同来源收集的数据准备数据模型并进行分析。您需要开发一个软件系统，供用户查询有关牛津郡不同地区的房价和市政税收费的信息。

牛津郡有多个区（或地方管理局），包括牛津市（City of Oxford）、切尔韦尔区（Cherwell）、南牛津郡（South Oxfordshire）、白马谷（Vale of White Horse）和西牛津郡（West Oxfordshire）。每个区（地方管理局）都有不同的区域或选区。例如，牛津市包含 Barton and Sandhills、Summertown、Headington、Cowley 等选区。同样，白马谷区包括 Abingdon Abbey Northcourt、Cumnor 和 Faringdon 等选区。

数据来源

您需要从不同的数据来源中收集有关房价和市政税收费的数据。数据需要通过手动或自动方式进行清理，并存储在 SQL 数据库中（参见评分标准）。

您必须使用由英国政府或公共机构公开发布的数据集，这些数据可以供英国公众访问。以下是一些示例数据来源：
1.	国家统计局 (ONS) 数据：
“按选区划分的中位价格，英格兰和威尔士，1995年12月至2022年12月”
数据链接
2.	HM 土地登记处开放数据：
价格支付数据 数据链接
3.	市政税数据：
牛津郡各区市政信息 链接

示例：
•	切尔韦尔区市政税收费：
收费详情
•	牛津市市政税收费：
收费详情

任务

使用收集到的数据，您需要生成一个统一的数据集和模型，用于开发该系统。必须确保所有使用的数据都规范化为 3NF（第三范式）。数据需要存储在 SQL 数据库系统（SQLite）中，并在 R 中查询数据（具体要求如下）。

您需要撰写一份报告，解释您为收集、清理和结构化数据以及实施系统所采取的所有过程（参见评分标准以了解详细要求）。

以下是实施系统需要完成的任务：

SQL 数据库

	1.	规范化数据：
将数据规范化为 3NF 并存储在多个 SQL 数据库表中。
2.	定义数据库结构：
定义适当的主键、数据类型以及表之间的关系。

使用 R 编写 SQL 查询

	3.	计算某区选区的房价平均值：
	•	计算某区（例如牛津市、切尔韦尔区等）某选区在两年的房价平均值。例如，2021年和2022年的房价平均值。
	•	注意：每年的房价按季度划分（例如2021年3月、2021年6月等），计算年度平均值时需要考虑这些季度数据。
	4.	找出某区房价最高的选区：
	•	针对某区的特定年份和季度（例如2021年3月或2019年12月），找出房价最高的选区。
	5.	计算某区某城镇的平均市政税：
	•	基于市政税收费数据，为某区某城镇计算特定三类物业的平均市政税收费（例如切尔韦尔区班伯里镇中Band A, B, C的平均市政税）。
	6.	计算同一区不同城镇间市政税差异：
	•	比较同一区（例如切尔韦尔区）中不同城镇（例如 Barford 和 Bicester）相同物业类别（例如 Band A）的市政税收费差异。
	7.	找出某区市政税最低的城镇：
	•	在某区（例如切尔韦尔区）内，找出 Band B 市政税收费最低的城镇。

评分标准

数据选择与清理（10分）

描述您为识别、获取、清理和使用房价、市政税等数据集而采取的步骤。阐明您所使用方法的依据，确保数据选择和清理符合质量标准。

结构化与半结构化数据（4分）

描述结构化数据模型（SQL）和半结构化数据模型（XML），并提供建议应使用 SQL、XML 还是两者结合。给出清晰的理由。

数据模型与实施（6分）

设计 SQL 数据库表：包括数据的 3NF 规范化设计，主键、关系及数据类型定义的正确性，并解释规范化过程。

R 代码设计与执行（20分）

	•	R 代码设计的结构良好，注释清晰（5分）。
	•	执行与测试：R 和 SQL 查询返回正确结果的测试与解释（每个任务 3 分，总计 15 分）。

提交要求

	•	提交截止时间：2024年12月9日（第12周），下午1点。
	•	提交内容：
	•	提交 R 代码和 SQL 数据库的电子版。
	•	提交报告的电子版（不超过 2000 字，R 和 SQL 代码不计入字数）。
	•	提交一段不超过 3 分钟的视频，展示系统完成任务的功能。
	•	最终评分与反馈将在考试委员会结束后发布。