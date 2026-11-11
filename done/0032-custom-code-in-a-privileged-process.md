---
Title: How borg came about
Date: 2026-11-11
Category: security
Tags: synthesizer, work, security, linux
---

#### ... and why you should never trust custom code in a privileged process


This short article will explain how borg can exist as a non-invasive extension
framework, and what could have been done to prevent it. But also shortly goes
into the ethical side of the discussion; should you prevent this?


## The logue SDK and the Korg drumlogue

When Korg started with the [Logue SDK](https://korginc.github.io/logue-sdk/) in
2019, they released a set of development instructions to create custom
synthesizer oscillators and effects. They created a custom binary format and
metadata that was zipped, and this would be uploaded to a device's runtime. These
devices were the Prologue, Minilogue XD, and the programmable synthesizer kit
NTS-1.

All were based around a STM32 main processor, optional co-processor(s) and analog
voice circuitry. This customization would allow sounds and effects to take the
device beyond imagination. 

In 2024 they released an improved SDK which moved to an ELF format which improved
the tooling, allowed dynamic loading, and targeted a slightly updated chipset.
However, they were still essentially armhf. This change was essential for future
devices like the drumlogue and microKORG2, which were application processors
running a Linux variant and synth units would be able to use file-loading.

This allowed people to develop even more interesting capabilities, such as
loading soundfonts, or playing tracker files, and more. If you allow your device
to run custom-code, you also need to be aware of the consequences.


## Units inherit the daemon's privileges

I can only guess as to why, but synth units run as root. That is not a bug I
found. It is how the device is set up, and it is why borg can exist without
changing anything on the rootfs.

On the drumlogue, a unit is not sandboxed from the system. It runs inside
`drumlogued`, and that daemon runs as root. A unit can therefore read and write
the filesystem. This is not a hidden channel or an exploit. It is the ordinary
result of loading third-party code into a privileged process.

I have hit this by accident. A unit build left files in `/`, and cleaning them
up needed access the normal user path does not provide. I did not intend that,
and that is exactly the point: if someone who knows the device can do it
unintentionally, it will happen more widely to inexperienced users. This
observation is important because it also explains what a proper fix would look
like.

It is important to understand the consquences. A malicious or poorly written
unit can modify the device, write repeatedly to NAND/eMMC memory and wear
it out, interfere with normal operation and leave the filesystem in a state
that needs recovery. This latter point is a concern, as currently there is no
way for a user to initiate a recovery.

The ability to do these things is not unique to borg. Borg only demonstrates
the level of access already available to any loaded unit.


## What Borg does with that

[Borg](https://borg.rgrv.nl) is a small shared library that acts as a means to
extend the functionality of the device. It does so in a non-invasive way, by not
leaving stuff behind.  It does, however allow borg to extend the functionality of
the main process by being in-between existing operations.

Borg is small on purpose. When you fire a `GateOn()`, the instruction to play
a note:

1. It stages a preload object in `/tmp`.
2. It calls `execve("/proc/self/exe")` with `LD_PRELOAD`.
3. The daemon restarts in place, same pid, with the extension loaded.

No file on the rootfs is replaced. No firmware image is patched. Remove power
and nothing remains. The menu, the MIDI transform and the module loader live in
the running process, not on the device.

`LD_PRELOAD` is a standard Linux dynamic linker trick. By pointing it to a custom
shared library before restarting the process via `execve()`, it forces the OS to
load functions ahead of the original binaries.

This unlocks in-memory function interception (hooking) and transformation of
those functions; like modifying the return values or suppressing them in its
entirety. 

It can inspect incoming MIDI events, hijack display buffers to draw custom menu pages, or inject new functionality.


## What it is not
It is also important to understand what it is not. As in recent times a lot
of discussions is about custom and vibecoded firmware, that is either completely
new or in some cases reverse-engineered. Borg is not any of those.

- Not custom firmware. The rootfs is unchanged. There is no image to flash and
  no permanent install.
- Not reverse engineering. No disassembly, no decompilation, no extracted
  vendor code, no modified manufacturer code. Everything comes from the public
  logue SDK, the documented unit model, and standard Linux behavior.
- Not a vulnerability in the manufacturer's code. It is the permission model
  doing what it was configured to do.


## Why this is not an exploit
An exploit bypasses a security boundary.

Borg does not bypass a security boundary. The loaded unit is already executing
with the same privileges as the process hosting it. Borg merely demonstrates
what those permissions make possible when custom code is executed inside a
privileged process.

Whether that permission model is desirable is a separate question, but the
behavior described here follows directly from the design of the system.


## The fix is ordinary Linux

As I mentioned earlier, I can only guess to why this permission was given, as
certain safeguards for custom code execution aren't in place.

Running units as root may have simplified development and reduced friction
between the audio engine, hardware interfaces, storage access and update
mechanisms. From an engineering perspective, fewer privilege boundaries often
mean fewer things that can break. The tradeoff is that every extension inherits
that trust.

The risk that exists is real, as it is possible to render the device inoperable.
And with the current influx of vibecoded modifications this risk is even more
real than ever before.

An extension model can exist without giving every unit the whole machine:

- Mount the rootfs read-only.
- Run each service under its own user.
- Put audio in an `audio` group with access only to the devices it needs.
- Give units only the paths and devices their role requires.

None of this is new. It is how a Linux system is normally hardened. The
current design makes experimentation easy. It also makes accidents and abuse
easy.

None of these measures would prevent extension frameworks from existing. They
would simply ensure that extension code cannot modify parts of the system
unrelated to its intended purpose.


## Why I built it

Because the instrument is capable, the SDK is public, and the extension point is
already there. Borg makes that point usable: an in-process extension framework
with menu pages, MIDI transforms and modules loaded from the user filesystem. It
adds capability without touching the system underneath.

By documenting how the system behaves and where the boundaries are, developers
can make more informed decisions when building extensions, whether they are
writing code themselves or using AI-assisted tooling.


## Ethical question

If the device is ever locked down properly, that is a good change. Borg would
stop working, and that might be the correct outcome. Until then, the honest
description is this: units run as root, and borg uses the room that model
leaves.

However, is that the right approach? You are essentially the owner of the
device. And in my opinion you should be able to do with it what you want. It
should not be the manufacturer restricting you when no malicious use is
intended.

Though, they are responsible for preventing the user from making the device
inoperable either when it concerns normal use; as that is the balance here.
If an inexperienced user would download a custom synth unit, it could have
his device rendered inoperable, as nothing prevents writing to disk.

## Why is it called borg?

The name borg was chosen for several reasons. The name is often associated
with a well-known science-fiction series, in which lifeforms are augemented
and absorbed into a collective. It also means castle in North Germanic
languages, and is related to the word 'burg' in German and 'borough' in
English. This is a fortified structure, built inside an existing landscape.
I found these a nice metaphor for what the framework does.


## Closing

Borg is not interesting because it uses `LD_PRELOAD`; Linux systems have
supported techniques like that for decades. What is interesting is that a
musical instrument runs third-party code this way, and where the
boundaries are placed.

The takeaway isn't that borg exists. People will always find new ways to
extend the devices they own. The more important lesson is much older: once
untrusted code runs inside a privileged process, that code inherits the
trust of the host. Borg is a consequence of that design. It simply makes
use of it.

Sometimes intentionally, sometimes accidentally.
