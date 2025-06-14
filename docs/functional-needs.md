# Функциональные требования для проекта SQLRC

## 1. Введение

SQLRC - это инструмент командной строки, который генерирует код на языке Go на основе SQL-файлов. Основная цель проекта - автоматизировать создание структур данных и функций для работы с базой данных, инкапсулируя логику вызова базы данных через стандартную библиотеку `database/sql`.

## 2. Общие требования

### 2.1. Назначение системы

Система должна обеспечивать:
- Парсинг SQL-файлов со схемой базы данных (CREATE TABLE)
- Парсинг SQL-файлов с запросами, содержащими параметры
- Генерацию Go-кода для работы с базой данных
- Простую конфигурацию через текстовый файл

### 2.2. Целевая аудитория

- Разработчики на Go, работающие с базами данных
- Команды разработки, использующие SQL для определения схемы данных
- Разработчики, желающие автоматизировать создание кода для работы с базой данных

## 3. Функциональные требования

### 3.1. Парсинг схемы базы данных

Система должна:
- Читать SQL-файлы с определениями таблиц (CREATE TABLE)
- Извлекать имена таблиц и их структуру
- Поддерживать базовые типы данных (TEXT, INTEGER)
- Определять, является ли поле обязательным (NOT NULL)
- Игнорировать комментарии в SQL-коде

### 3.2. Парсинг запросов

Система должна:
- Читать SQL-файлы с запросами
- Распознавать специальные комментарии формата `--@ sqlrc:ИмяФункции:ТипВозврата`
- Поддерживать три типа возвращаемых значений: one, many, exec
- Распознавать параметры запросов в формате `<@имя_параметра:тип_параметра@>`
- Поддерживать базовые типы параметров: string, int
- Обрабатывать повторяющиеся параметры в запросе

### 3.3. Генерация кода

Система должна генерировать:
- Структуры Go для таблиц базы данных
- Структуры для параметров запросов
- Структуры для результатов запросов
- Функции для выполнения запросов
- Константы с SQL-запросами

### 3.4. Конфигурация

Система должна поддерживать конфигурацию через текстовый файл в формате "key:value\n" со следующими параметрами:
- `schema` - путь к файлу схемы SQL
- `queries` - путь к файлу запросов SQL
- `remove_trailing_s` - флаг для удаления окончания "s" из имен таблиц
- `pakage.name` - имя пакета Go
- `pakage.path` - путь к директории, в которую будут сгенерированы файлы

### 3.5. Интерфейс командной строки

Система должна предоставлять простой интерфейс командной строки:
- Запуск с параметром `--cfg <путь_к_конфигурационному_файлу>`
- Вывод информации о ходе выполнения
- Вывод сообщений об ошибках

## 4. Ограничения и допущения

### 4.1. Поддерживаемые типы данных

- SQL: TEXT, INTEGER
- Go: string, int

### 4.2. Поддерживаемые типы запросов

- one - запрос, возвращающий одну запись
- many - запрос, возвращающий несколько записей
- exec - запрос, не возвращающий данные (INSERT, UPDATE, DELETE)

### 4.3. Поддерживаемые типы параметров

- string - строковый тип
- int - целочисленный тип

### 4.4. Технические ограничения

- Реализация на языке Pascal (Free Pascal Compiler)
- Отсутствие встроенной поддержки регулярных выражений
- Использование простых текстовых функций для парсинга

## 5. Примеры использования

### 5.1. Пример конфигурационного файла

```
schema:schema.sql
queries:user.sql
remove_trailing_s:true
pakage.name:gen
pakage.path:./__gen/
```

### 5.2. Пример файла схемы SQL

```sql
CREATE TABLE users (
    primary_currency TEXT NOT NULL DEFAULT 'BYN',
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    image TEXT NOT NULL,
    id INTEGER PRIMARY KEY NOT NULL,
    balance INTEGER NOT NULL DEFAULT 0
);
```

### 5.3. Пример файла запросов SQL

```sql
--@ sqlrc:GetSingle:one
SELECT *
FROM users
WHERE username = <@username:string@>;

--@ sqlrc:GetMany:many
SELECT users.* FROM users WHERE id < <@id:int@>;

--@ sqlrc:InsertUser:exec
INSERT INTO users (username, password, image)
VALUES (<@username:string@>, <@password:string@>, <@image:string@>);
```

### 5.4. Пример использования

```bash
sqlrc --cfg example/config.txt
```

## 6. Критерии качества

### 6.1. Корректность генерации

- Сгенерированный код должен компилироваться без ошибок
- Структуры данных должны соответствовать схеме базы данных
- Функции должны корректно выполнять запросы

### 6.2. Производительность

- Время генерации кода должно быть приемлемым для использования в процессе разработки
- Сгенерированный код должен эффективно работать с базой данных

### 6.3. Удобство использования

- Простая конфигурация
- Понятные сообщения об ошибках
- Минимальные требования к настройке
