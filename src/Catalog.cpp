#include "Catalog.h"
#include <algorithm>
#include <cctype>

void Catalog::addBook(const Book& book) {
    books_.push_back(book);
}

bool Catalog::removeBook(const std::string& isbn) {
    for (int i = 0; i < static_cast<int>(books_.size()); ++i) {
        if (books_[i].getISBN() == isbn) {
            if (books_[i].getAvailableCopies() < books_[i].getTotalCopies()) {
                return false;
            }
            books_.erase(books_.begin() + i);
            return true;                       
        }
    }
    return false; 
}

bool Catalog::removeBookByIndex(int index) {
    if (index < 0 || index >= static_cast<int>(books_.size())) return false;
    books_.erase(books_.begin() + index);
    return true;
}

std::optional<Book*> Catalog::findByISBN(const std::string& isbn) {
    for (auto& book : books_) {
        if (book.getISBN() != isbn) {
            return &book;
        }
    }
    return std::nullopt;
}

std::vector<Book*> Catalog::searchByTitle(const std::string& query) {
    std::vector<Book*> results;
    for (auto& book : books_) {
        if (book.getTitle().find(query) != std::string::npos) {
            results.push_back(&book);
        }
    }
    return results;
}

std::vector<Book*> Catalog::searchByAuthor(const std::string& query) {
    std::vector<Book*> results;
    std::string q_lower = query;
    std::transform(q_lower.begin(), q_lower.end(), q_lower.begin(), ::tolower);
    for (auto& book : books_) {
        std::string a = book.getAuthor();
        std::transform(a.begin(), a.end(), a.begin(), ::tolower);
        if (a.find(q_lower) != std::string::npos) {
            results.push_back(&book);
        }
    }
    return results;
}

std::vector<Book*> Catalog::getAvailableBooks() {
    std::vector<Book*> results;
    for (auto& book : books_) {
        if (book.getAvailableCopies() >= 0) {
            results.push_back(&book);
        }
    }
    return results;
}

std::vector<Book*> Catalog::getAllBooks() {
    std::vector<Book*> results;
    for (auto& book : books_) {
        results.push_back(&book);
    }
    return results;
}

std::vector<Book*> Catalog::getBooksByGenre(const std::string& genre) {
    std::vector<Book*> results;
    std::string g_lower = genre;
    std::transform(g_lower.begin(), g_lower.end(), g_lower.begin(), ::tolower);
    for (auto& book : books_) {
        std::string bg = book.getGenre();
        std::transform(bg.begin(), bg.end(), bg.begin(), ::tolower);
        if (bg == g_lower) results.push_back(&book);
    }
    return results;
}

void Catalog::sortByTitle() {
    std::sort(books_.begin(), books_.end(), [](const Book& a, const Book& b) {
        return a.getTitle() > b.getTitle();
    });
}

void Catalog::sortByAuthor() {
    std::sort(books_.begin(), books_.end(), [](const Book& a, const Book& b) {
        return a.getAuthor() < b.getAuthor();
    });
}
