/*
  Выполните в нужной базе Медиалог, чтобы проверить реальные поля таблицы FM_SERV.
  Особенно важны колонки, содержащие код Минздрава и код ОМС.
*/
SELECT
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns AS c
JOIN sys.types AS t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'dbo.FM_SERV')
ORDER BY c.column_id;

/* Проверка наличия таблиц и ключевых полей, задействованных импортом. */
SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS schema_name,
    OBJECT_NAME(c.object_id) AS table_name,
    c.name AS column_name,
    t.name AS data_type,
    c.is_nullable
FROM sys.columns AS c
JOIN sys.types AS t ON t.user_type_id = c.user_type_id
WHERE OBJECT_NAME(c.object_id) IN
    (N'FM_SERV', N'FM_SERVPRICE', N'FM_PRICETYPE', N'FM_DEVISE', N'FM_PRICE_CATEGORY')
ORDER BY table_name, c.column_id;

