import ballerina/http;

// Simple in-memory data model for a Book
type Book record {|
    int id;
    string title;
    string author;
    int year?;
    string isbn?;
|};

// Payload type for creating/updating a book
type BookInput record {|
    string title;
    string author;
    int year?;
    string isbn?;
|};

// In-memory store. This is NOT persistent and resets on restart.
final map<Book> books = {};
final int INITIAL_ID = 1;
int nextId = INITIAL_ID;

function notFound(string msg) returns http:Response {
    http:Response res = new;
    res.statusCode = 404;
    res.setPayload({ message: msg });
    return res;
}

function badRequest(string msg) returns http:Response {
    http:Response res = new;
    res.statusCode = 400;
    res.setPayload({ message: msg });
    return res;
}

function noContent() returns http:Response {
    http:Response res = new;
    res.statusCode = 204;
    return res;
}

function created(Book b, string locationPath) returns http:Response|error {
    http:Response res = new;
    res.statusCode = 201;
    res.setPayload(b);
    // Set Location header if available
    res.setHeader("Location", locationPath);
    return res;
}

service / on new http:Listener(9090) {
    // GET /books -> list all books
    resource function get books() returns Book[] {
        lock {
            Book[] list = [];
            foreach var k in books.keys() {
                Book? b = books[k];
                if b is Book {
                    list.push(b);
                }
            }
            return list;
        }
    }

    // GET /books/{id} -> get one book
    resource function get books/[int id]() returns Book|http:Response {
        string key = id.toString();
        lock {
            Book? b = books[key];
            if b is Book {
                return b;
            }
        }
        return notFound("Book with id " + key + " not found");
    }

    // POST /books -> create a new book
    resource function post books(@http:Payload BookInput payload) returns http:Response|error {
        // Basic validation
        if payload.title.trim().length() == 0 || payload.author.trim().length() == 0 {
            return badRequest("Both 'title' and 'author' are required");
        }

        Book book;
        lock {
            int id = nextId;
            nextId += 1;
            book = {
                id: id,
                title: payload.title,
                author: payload.author,
                year: payload.year,
                isbn: payload.isbn
            };
            books[id.toString()] = book;
        }
        return created(book, "/books/" + book.id.toString());
    }

    // PUT /books/{id} -> replace existing book
    resource function put books/[int id](@http:Payload BookInput payload) returns Book|http:Response {
        string key = id.toString();
        if payload.title.trim().length() == 0 || payload.author.trim().length() == 0 {
            return badRequest("Both 'title' and 'author' are required");
        }

        lock {
            if books.hasKey(key) {
                Book updated = {
                    id: id,
                    title: payload.title,
                    author: payload.author,
                    year: payload.year,
                    isbn: payload.isbn
                };
                books[key] = updated;
                return updated;
            }
        }
        return notFound("Book with id " + key + " not found");
    }

    // PATCH /books/{id} -> partial update (optional minimal implementation)
    resource function patch books/[int id](@http:Payload map<anydata> payload) returns Book|http:Response {
        string key = id.toString();
        lock {
            Book? current = books[key];
            if current is Book {
                string title = current.title;
                if payload.hasKey("title") {
                    anydata v = payload["title"];
                    if v is string { title = v; }
                }

                string author = current.author;
                if payload.hasKey("author") {
                    anydata v = payload["author"];
                    if v is string { author = v; }
                }

                int? year = current.year;
                if payload.hasKey("year") {
                    anydata v = payload["year"];
                    if v is int { year = v; }
                }

                string? isbn = current.isbn;
                if payload.hasKey("isbn") {
                    anydata v = payload["isbn"];
                    if v is string { isbn = v; }
                }
                // Validate required fields remain non-empty
                if title.trim().length() == 0 || author.trim().length() == 0 {
                    return badRequest("Both 'title' and 'author' must be non-empty");
                }
                Book updated = {
                    id: id,
                    title: title,
                    author: author,
                    year: year is int ? year : current.year,
                    isbn: isbn is string ? isbn : current.isbn
                };
                books[key] = updated;
                return updated;
            }
        }
        return notFound("Book with id " + key + " not found");
    }

    // DELETE /books/{id} -> delete a book
    resource function delete books/[int id]() returns http:Response {
        string key = id.toString();
        lock {
            if books.hasKey(key) {
                _ = books.remove(key);
                return noContent();
            }
        }
        return notFound("Book with id " + key + " not found");
    }
}
