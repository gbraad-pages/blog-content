---
Title: Object Design
Date: 2016-09-23
Category: Books
Tags: review, summary, books, recommended
---

One of the books I got recommended early in my career was [Object Design][object design]: Roles, Responsibilities, and Collaborations by Rebecca Wirfs-Brock and Alan McKean. The topic of this book is OOD (Object-Oriented Design). It is a wordy book, which could certainly could have been shorter, but the content makes certainly up for this issue. This write-up is based on reading this book many years ago, so bear with me if things are not completely in line with the book. Although, the knowledge in this book certainly has contributed to this point-of-view. I currently own a copy of this book as reference in a digital format. 

![Object Design](https://d2arxad8u2l0g7.cloudfront.net/books/1372040740l/179204.jpg)

The author, Rebecca Wirfs-Brock, is a software engineer and consultant in Object-Oriented Design, and as the title suggests the book details about the design of your object model and how it interacts with other objects. 

One of the things you will learn when creating software, is that design of the  interactions and relations between objects and classes probably is one of the most important and hardest things. Luckily, software design and development is an evolutionary process. You will not get it right he first time and you also shouldn't aim for this. What can be modeled today as a variable on an object today, might become a class itself in the future. If you would design this from day one, you probably over-design the software and implement functionality that might never be needed.

What I learned from this book is how this interaction and collaboration between objects happen. Where do I keep the state? who can make a change? If the object can encapsulate it, this is probably where it should live. Ask yourself, why would another object need to know about the information, and whose responsibility is it? The book details as far as I remember CRC-cards (Class Reponsibility Rollaboration) and shows a method to get this clear. In my work I have never created the actual cards, but the concept behind it is very valuable. Get this book and browse through it, keep a copy as a reference. It is well worth it.

More information about this book can be found in my Knowledge Base [entry][object design].

[object design]: https://gitlab.com/gbraad/knowledge-base/blob/master/books/object-design.md "Object Design"