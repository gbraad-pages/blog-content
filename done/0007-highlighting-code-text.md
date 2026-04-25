---
Title: Highlighting of Code and Text
Date: 2016-09-09
Category: Misc
Tags: highlighting, code, language
---

Code is read more often than it is written. Nothing is truer than this statement. This means that when writing code it is important to have a good idea of what you are doing. Write clean code, which is simple or easy to reason about. Since if you can't explain it, how could others even understand it well. Syntax highlighting of code can help. With this, certain keywords or structure get emphasized by using a color. I do not think it is an ideal solution, but subconsciously it seems I focus more on the code. Likely, the colors themselves are pleasing to look at.

## Pleasant to the eyes
Perhaps because of this last, I tend to always implement or set the [Tomorrow Theme](https://github.com/chriskempson/tomorrow-theme) for my color scheme, and specifically the [Night Bright](https://github.com/chriskempson/tomorrow-theme#tomorrow-night-bright) variant. Below you can find an example, as I also enabled it on my blog by implementing a Pygments style.

## Example
`server.js`
```javascript
'use strict';

// get port from environment settings for deployment on Heroku
var EXPRESS_PORT = process.env.OPENSHIFT_NODEJS_PORT || process.env.PORT || 4000;
var EXPRESS_IPADDR = process.env.OPENSHIFT_NODEJS_IP || process.env.IPADDR || '127.0.0.1';
var EXPRESS_ROOT = __dirname;

function startExpress(root, port, ipaddr) {
  var express = require('express');
  var app = express();
  app.use(express.static(root));
  app.listen(port, ipaddr, function() {
    console.log('Listening on %s:%d',
		ipaddr, port);
  });
}

startExpress(EXPRESS_ROOT, EXPRESS_PORT, EXPRESS_IPADDR);
```

![](http://cdn.gbraad.nl/images/blog/javascript-syntax-highlighting.png)


## Implementations
Chris Kempson now has a new color scheme called 'base16`and it has a '[Tomorrow](https://chriskempson.github.io/base16/#tomorrow)' variant. It must be the name as I always install 'Tomorrow' first. Here are some of the Night Bright variants I have made over the years:

  * [Pygments](https://github.com/gbraad/pygments-style-tomorrownightbright)
  * [Chrome DevTools](https://github.com/gbraad/chrome-devtools-tomorrow-night-bright-theme)
  * [Brackets](https://github.com/gbraad/brackets-themes-TomorrowNightBright)
  * [CodeMirror](https://github.com/codemirror/CodeMirror/blob/master/theme/tomorrow-night-bright.css)
  * ...


## How about language
Since my wife and I are very involved in teaching, I have also experimented with the idea of using word or word-class highlighting for English. The results are that it can actually help. Words that need to be stressed, or emphasized, can be highlighted in a different color. Think of words like 'very', 'never', etc. Some of this can be automated, as can be seen in the following examples:

  * [NLP-compromise](http://nlp-compromise.github.io/website/), Text Parsing
  * [English-text-highlighting](http://evanhahn.github.io/English-text-highlighting/)
  * [English syntax highlighter](https://english.edward.io/)
  * [Knwl.js](https://github.com/loadfive/Knwl.js)

These implementations range from simple hard-coded word matching, to actual Natural Language Processing.


## Example
Take for instance the following example of `Alice In Wonderland - Down the Rabbit Hole`.

**"**There was nothing so very remarkable in that; nor did Alice think it so very much out of the way to hear the Rabbit say to itself, _'Oh dear! Oh dear! I shall be late!'_ (when she thought it over afterwards, it occurred to her that she ought to have wondered at this, but at the time it all seemed quite natural); but when the Rabbit actually took a watch out of its waistcoat-pocket, and looked at it, and then hurried on, Alice started to her feet, for it flashed across her mind that she had never before seen a rabbit with either a waistcoat-pocket, or a watch to take out of it, and burning with curiosity, she ran across the field after it, and fortunately was just in time to see it pop down a large rabbit-hole under the hedge.**"**

 When `adverb`, `verb`, `conjunction`, etc. are highlighted, the text will look as follows:
 
![](http://cdn.gbraad.nl/images/blog/english-text-highlighting.png)

Note: this is taken from [English syntax highlighter](https://english.edward.io/). Try and see for yourself if it can help.


## Chinese
Highlighting does not only work well for English. Chinese for instance is a tonal language. Which means that a pronounciation of a character can have a different tone for a different meaning. When not proprerly mastered, this can lead to a lot of confusion or embarrassment. For learner's of Chinese it is actually common to highlight the tones. An example of this is shown here:

```
welcome

v.t.
欢迎 huānyíng;  迎接 yíngjiē

Welcome home again!

欢迎你又回家了!

Huānyíng nǐ yòu huíjiā le!
```

![](http://cdn.gbraad.nl/images/blog/chinese-tone-highlighting.png)


## Conclusion
Highlighting can serve different purposes. I can not recall that highlighting actually helped me to write clean or correct code, or that it even prevented me from making a mistake or typo. However, it can certainly provide a plesant feeling, in which you can 'feel good' about your code in another way. For languages, such as English and Chinese, it can assist with the learning process.
