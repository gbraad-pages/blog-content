---
Title: "Task management and Personal Kanban: how I use GitLab Issues"
Date: 2016-10-09
Category: Misc
Tags: continuous improvement, management, knowledge, kanban, gitlab
---

Working on personal and work-related tasks can be overwhelming, especially when
you lose sight of what actually needs to be done. What makes it more difficult
is that you are constantly interrupted. I have tried many different things, and
apps, but nothing really worked. Do not try to make your process of working to
fit the tool, but make sure you have a tool that fits the way you work.


## Kanban
Kanban (or 看板) originated as a scheduling system to improving manufacturing
efficiency. The word literally means signboard in Japanese, and in Chinese it
can be read as 'Look board'. It emphasizes on visualization of tasks that need
to be done, are being worked on, and have finished.

In software development you often see people use Trello or other kanban-like
boards to visualize work that is on their 'backlog', 'doing', 'done'. Although
these tools work quite well, it did not fit my workflow or where I do most of
my work.

## GitLab issues
Quite recently, GitLab released a version of their sourcecode management tool
that allows to visualize issues on a board. And I started to evaluate it, as
GitLab is part of my workflow in general. I host many of my private
repositories there for backup purposes, use it to publish my resume with the
CI runners, etc. And I can tell you, that the issue boards was exactly what I
was looking for.

Below is a screenshot of what it looks like:
![](//cdn.gbraad.nl/images/blog/kanban-gitlab.jpg)

Note: the image shown here is from an early iteration and still has too
many items in 'doing'. This actually made me realize where my time was spent.


### How to set-up
All you need to do is create a private repository. In my case, I created a
'personal' project. All the issues you create, will only be visible to you.
After you have done this, you can create a board from the Issues. Just start
with the defaults first and customize it along the way... This made it
work best for me.

### Workflow
When you create an issue, just tag it accordingly. I use it to group
tasks for different topics or things I work on. Now when you open the
board, you will see your issue is on the 'backlog'. From there you can
drag it to a swimlane. I have several that helps to organize tasks,
such as 'blog' and 'urgent'. When you drag, it will assign the label
to the issue according to the name of the swimlane.

### Offline use?
There is, however, a small issue with the setup. It only allows me to work
online. In the end I noticed this is actually not a big problem.

## Single-tasking
Kanban helps you to visualize your tasks at hand, but it still requires 
discipline to actually make it work. Therefore, you need to understand that
'multi-tasking' does not exist! I recently read 'Singletasking: Get More
Done-One Thing at a Time', and it help me a lot to realize that I was
going the right direction with my personal kanban. However, I was still
trying to do too many things at once. Mostly due to interruptions. This
led me to appreciate the offline problem I have.

If I have an interruption, or some other urgent matter, I would first
record it on my phone in a file called 'reminder', which lives in the same
personal repository. This file is synced using git, so it travels with me
and it allows me to use it as a general reminder/todo record keeping,
and decide later what to do with the entries.


## Tools
On my desktop I only need to use a browser to keep track of tasks
being worked on. Even the reminder file can be opened from here.

On my phone I use the following apps:
![](//cdn.gbraad.nl/images/blog/kanban-apps-on-phone.jpg)

Writeily Pro, SGit, and Labcoat. Using SGit I sync several important
repositories to my phone, such as my 'personal', 'knowledge-base',
and some private specific projects for training/teaching, etc.

Writeily Pro opens the SGit repos folder as it's document folder:
`/sdcard/Android/data/me.sheimi.sgit/files/repo` in my case. Writely's
usage was not without problems for me. Especially when dealing with
some 'larger' files.

Using Labcoat I am able to create and change basic information of an
issue, such as closing it and adding comments. But I usually do all
interactions online now, and else use my offline reminder file. I
only use Labcoat only in rare cases. Probably also because the tool
misses some of the more wanted features as labelling and tagging
issues.

I haven't found a good way to use the command line yet. I did start
with a small [client](https://gitlab.com/gbraad/gitlab-client), but so
far it only reads and doesn't filter anything. Hope I can allocate more
time to deal with this at some point. At the moment I do not really
need it.


## Conclusion
Task management is not something you learn by just reading a book or
keeping a todo-list inside an application. It really is a discipline.
And it depends on you, how you will deal with it. This article does not
go into a lot of detail on my own process, as this is a personal quest.
Just experiment and see what works best for you.

I have read several books, and in the section 'More information' below,
you can find these resources. It involves in keeping your tasks
*visualized* and *limiting* the amount you work on at the same time. It
is up to you how to balance private and work.

I also learned that to keep things organized, I started to keep a public
[knowledge base](https://gitlab.com/gbraad/knowledge-base/). This way I
am better able to keep knowledge available and at hand. Before, I would
keep it in an earlier version of a reminder file and this cluttered
everything and actually not made me remember things. I am still working
on writing things done in a more general way, written towards possible
others who will read it. But this is a work-in-progress, as part of my
personal continous improvement.

I will certainly refine my process over time, and might even change it
again completely. As long as it works for me. I'll keep you updated and
might write related articles about time management and knowledge
techniques I have used over the years. One I still love the most is
mind-mapping... and I have applied it to organizing work before. It is
a great way to organize thoughts.


## More information
I suggest to read more about personal kanban.

  * [Personal Kanban 101](http://www.personalkanban.com/pk/personal-kanban-101/)
  * Knowledge-base: [Personal kanban](https://gitlab.com/gbraad/knowledge-base/blob/master/books/personal-kanban.md)
  * Knowledge-base: [Singletasking](https://gitlab.com/gbraad/knowledge-base/blob/master/books/singletasking.md)
  * [Presentation](https://hguemar.fedorapeople.org/personal-kanban/) of a friend's experience with Personal Kanban
