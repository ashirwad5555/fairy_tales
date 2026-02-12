import 'package:flutter/material.dart';
import '../models/story_category.dart';
import '../models/story_book.dart';

final List<StoryCategory> categories = [
  StoryCategory(
    name: 'Motivational',
    icon: Icons.star_rounded,
    color: const Color(0xFFFFB347),
    books: [
      StoryBook(
        title: 'The Little Engine That Could',
        coverImage: '🚂',
        coverColor: const Color(0xFF87CEEB),
        author: 'Watty Piper',
        lottieAnimation: 'train',
        story:
            '''Once upon a time, there was a little blue engine who loved to help. One day, she found a long train of toys and treats that needed to get over a big mountain to the children on the other side.

"Can you help us?" asked the dolls and teddy bears.

The little engine had never climbed such a big mountain before, but she looked at all the happy toys and said, "I think I can! I think I can!"

As she started up the mountain, puffing and chugging, she kept repeating: "I think I can! I think I can! I think I can!"

The mountain was steep and the little engine was tired, but she never gave up. With each chug, she got closer to the top.

Finally, she reached the peak! "I thought I could! I thought I could!" she said happily as she rolled down the other side.

The children were so happy to receive their toys and treats, and the little engine learned that believing in yourself can help you achieve anything!

The End.

Remember: When something seems hard, just keep saying "I think I can!" and give it your best try!''',
      ),
      StoryBook(
        title: 'The Brave Little Bunny',
        coverImage: '🐰',
        coverColor: const Color(0xFFFFB6C1),
        author: 'Story Collection',
        story:
            '''In a cozy burrow lived Bella, a tiny bunny who was afraid of the dark forest.

One evening, Bella's little brother wandered too far and got lost. Even though she was scared, Bella knew she had to be brave.

She hopped into the dark forest, her heart pounding. "I can do this," she whispered to herself.

Following her brother's favorite song, she found him crying under a big oak tree. "Don't worry," Bella said, "I'm here now!"

Together, they followed the moonlight home. Bella realized that being brave doesn't mean you're not scared - it means doing what's right even when you are scared.

From that day on, Bella was known as the bravest bunny in the burrow!

The End.

Remember: Courage is being scared but doing it anyway!''',
      ),
    ],
  ),
  StoryCategory(
    name: 'Science',
    icon: Icons.science_rounded,
    color: const Color(0xFF98D8C8),
    books: [
      StoryBook(
        title: 'Journey to the Moon',
        coverImage: '🌙',
        coverColor: const Color(0xFF4A5899),
        author: 'Space Tales',
        lottieAnimation: 'rocket',
        story:
            '''Luna was a curious little girl who loved looking at the moon through her telescope every night.

"I wonder what it's like up there," she thought.

That night, she dreamed she was an astronaut! She put on her space suit, climbed into a rocket, and counted down: "5... 4... 3... 2... 1... BLAST OFF!"

The rocket zoomed through space, passing twinkling stars and colorful planets. When she landed on the moon, Luna bounced around in the low gravity!

"Wheee! I can jump so high here!" she giggled.

She collected moon rocks, planted a flag, and saw Earth hanging in the black sky like a beautiful blue marble.

"The moon has no air or water," she learned, "but it's still amazing!"

When Luna woke up, she knew she wanted to learn everything about space. Maybe one day, her dream would come true!

The End.

Fun Fact: The moon is about 384,400 kilometers away from Earth!''',
      ),
    ],
  ),
  StoryCategory(
    name: 'History',
    icon: Icons.castle_rounded,
    color: const Color(0xFFDDA0DD),
    books: [
      StoryBook(
        title: 'The Young Inventor',
        coverImage: '💡',
        coverColor: const Color(0xFFFFA500),
        author: 'Historical Tales',
        story:
            '''Long ago, there lived a curious boy named Thomas who loved to tinker with things.

While other children played, Thomas would take apart clocks and toys to see how they worked.

"Why do things work the way they do?" he always asked.

One day, Thomas tried to make a light without fire. People laughed at him. "It's impossible!" they said.

But Thomas didn't give up. He tried hundreds of different ways. Each time something didn't work, he said, "That's okay! Now I know one more way that doesn't work!"

Finally, after many tries, Thomas made a light bulb glow! The room filled with bright, warm light - no fire needed!

"I didn't fail," Thomas smiled. "I just found 1,000 ways that didn't work before finding the one that did!"

His invention changed the world, and Thomas Edison became one of history's greatest inventors.

The End.

Remember: Every mistake teaches us something new!''',
      ),
    ],
  ),
  StoryCategory(
    name: 'Technology',
    icon: Icons.computer_rounded,
    color: const Color(0xFF77DD77),
    books: [
      StoryBook(
        title: 'Robot\'s First Day',
        coverImage: '🤖',
        coverColor: const Color(0xFF6495ED),
        author: 'Future Stories',
        story:
            '''In a bright laboratory, a little robot named Chip woke up for the first time.

"Hello, world!" Chip beeped happily.

A kind scientist named Dr. Maya smiled. "Welcome, Chip! Let me teach you about the world."

Chip learned to recognize colors, count numbers, and even play music! But Chip wanted to do more.

"Can I help people?" Chip asked.

"Of course!" said Dr. Maya. "That's what technology is for - to help make life better!"

Chip helped organize books in the library, watered plants in the garden, and even read stories to children at bedtime.

"Technology is amazing when we use it to help others," Chip beeped proudly.

The children loved their new robot friend, and Chip learned that being helpful makes everyone happy!

The End.

Remember: Technology is a tool that works best when we use it to help others!''',
      ),
    ],
  ),
];
