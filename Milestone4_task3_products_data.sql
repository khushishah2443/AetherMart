USE aethermart_db;

ALTER TABLE Products
    ADD COLUMN product_description TEXT,
    ADD COLUMN product_vector VECTOR(384); -- NOTE: 384 is a common dimension.
                                          -- Change this to match your embedding model!

USE aethermart_db;

UPDATE Products SET product_description = 'A bag of gently used microchips. Tested and functional, perfect for hobbyist electronics projects or repairs. A sustainable and cost-effective choice.' WHERE product_id = 1;
UPDATE Products SET product_description = 'Experience luxury typing with our solid granite keyboard. Features mechanical switches and a unique, premium stone finish. Heavy, durable, and a true statement piece.' WHERE product_id = 2;
UPDATE Products SET product_description = 'Cryo-treated durable work pants. These ''Frozen'' brand trousers offer extreme durability and comfort, perfect for harsh conditions. (Not actually frozen).' WHERE product_id = 3;
UPDATE Products SET product_description = 'A standard pair of high-quality work gloves. Durable material, comfortable fit. Ideal for general-purpose tasks and protecting your hands.' WHERE product_id = 4;
UPDATE Products SET product_description = 'A minimalist and sturdy table. Perfect as a dining table, desk, or workstation. Features a clean design and simple assembly.' WHERE product_id = 5;
UPDATE Products SET product_description = 'An incredibly bouncy and durable play ball. Provides endless fun for kids, pets, or outdoor games. Brightly colored and easy to find.' WHERE product_id = 6;
UPDATE Products SET product_description = 'High-quality, farm-fresh whole chicken. Ready for roasting, grilling, or any culinary creation. Tender, juicy, and full of flavor.' WHERE product_id = 7;
UPDATE Products SET product_description = 'Industrial-grade steel-infused potato chips. Kidding! These are premium, kettle-cooked chips with a robust, savory flavor and an extra-crispy crunch.' WHERE product_id = 8;
UPDATE Products SET product_description = 'A brand new, modern-style table. Sleek design with a durable finish, perfect for contemporary homes or offices.' WHERE product_id = 9;
UPDATE Products SET product_description = 'A crisp, fresh, and bouncy new ball. Perfect for sports or play. This high-quality ball offers excellent performance and durability.' WHERE product_id = 10;
UPDATE Products SET product_description = 'A bag of pre-washed, fresh garden salad mix. Includes lettuce, spinach, and carrots. The perfect base for a healthy and delicious meal.' WHERE product_id = 11;
UPDATE Products SET product_description = 'A block of fresh, artisanal cheese. Creamy, flavorful, and perfect for slicing, shredding, or a charcuterie board.' WHERE product_id = 12;
UPDATE Products SET product_description = 'Artisanal rustic cheese with a firm texture, featuring embedded granite-like coloring from edible herbs. A gourmet experience.' WHERE product_id = 13;
UPDATE Products SET product_description = 'A brand new pair of stylish and comfortable pants. Modern fit, durable fabric. Ideal for casual wear or a night out.' WHERE product_id = 14;
UPDATE Products SET product_description = 'A fun and squeaky rubber ball for pets. Made from tasty, non-toxic rubber. Durable enough for heavy chewers and provides hours of fun.' WHERE product_id = 15;
UPDATE Products SET product_description = 'A lightweight plastic laptop computer. Ideal for students or basic tasks. Features a bright screen and all essential ports.' WHERE product_id = 16;
UPDATE Products SET product_description = 'A pair of pants sold as-is for repair or parts. May have tears, missing buttons, or broken zippers. Perfect for DIY fashion projects or fabric harvesting.' WHERE product_id = 17;
UPDATE Products SET product_description = 'Premium canned tuna in oil. Incredibly soft, tender, and flavorful. Perfect for sandwiches, salads, or pasta dishes. Wild-caught.' WHERE product_id = 18;
UPDATE Products SET product_description = 'An ultra-soft and comfortable t-shirt. Made from premium combed cotton, this shirt feels great against the skin. Perfect for everyday wear.' WHERE product_id = 19;
UPDATE Products SET product_description = 'Sleek, slim-fit pants made from a comfortable stretch-rubber-blend material. Water-resistant and flexible, perfect for an active lifestyle.' WHERE product_id = 20;
UPDATE Products SET product_description = 'A pair of generic, no-brand pants. Simple, functional, and affordable. A basic wardrobe staple for work or casual wear.' WHERE product_id = 21;
UPDATE Products SET product_description = 'A fantastic package of thick-cut, hardwood-smoked bacon. Crisps up perfectly. The ultimate breakfast companion.' WHERE product_id = 22;
UPDATE Products SET product_description = 'A refined, gourmet salad kit. Includes artisanal greens, premium toppings, and a high-quality vinaigrette. A sophisticated, healthy meal.' WHERE product_id = 23;
UPDATE Products SET product_description = 'Premium leather gloves. These high-priced gloves offer superior protection, dexterity, and a comfortable, broken-in feel.' WHERE product_id = 24;
UPDATE Products SET product_description = 'Gourmet rubber-like sausages with a refined, smoky flavor. A unique culinary delight for the adventurous foodie. Surprisingly delicious.' WHERE product_id = 25;
UPDATE Products SET product_description = 'A bar of all-natural soap with a rustic, wooden scent. Contains exfoliating wood chips and moisturizing oils. Handcrafted and eco-friendly.' WHERE product_id = 26;
UPDATE Products SET product_description = 'A pre-owned metal hat. This unique piece of headwear shows signs of wear, giving it a rustic, vintage look. A true statement piece.' WHERE product_id = 27;
UPDATE Products SET product_description = 'A standard pair of casual pants. Comfortable fit, durable twill fabric. Perfect for everyday wear, available in multiple colors.' WHERE product_id = 28;
UPDATE Products SET product_description = 'A fun, plastic pizza toy set for kids. Includes multiple slices and toppings. Encourages imaginative play.' WHERE product_id = 29;
UPDATE Products SET product_description = 'A pair of high-quality, comfortable walking shoes. Features cushioned insoles and a durable, non-slip sole. Perfect for daily walks or long days on your feet.' WHERE product_id = 30;
UPDATE Products SET product_description = 'A responsive and ergonomic computer mouse. Features high-precision optical tracking and programmable buttons. Ideal for work or gaming.' WHERE product_id = 31;
UPDATE Products SET product_description = 'Premium, free-range chicken, ready for cooking. Known for its superior taste and texture. Ethically raised and processed.' WHERE product_id = 32;
UPDATE Products SET product_description = 'A sleek, aerodynamic fish-shaped surfboard. Designed for speed and maneuverability in small to medium waves.' WHERE product_id = 33;
UPDATE Products SET product_description = 'A rustic, vintage-style bicycle. Features a steel frame, leather saddle, and classic design. Perfect for cruising around town in style.' WHERE product_id = 34;
UPDATE Products SET product_description = 'Comfortable and soft small-sized pants made from 100% pure cotton. Breathable and gentle on the skin, perfect for lounging or casual outings.' WHERE product_id = 35;
UPDATE Products SET product_description = 'A bag of ''Intelligent'' brand potato chips. Infused with smart nootropics? Probably not, but they are intelligently seasoned for maximum flavor.' WHERE product_id = 36;
UPDATE Products SET product_description = 'A family-sized bag of fresh, crisp salad mix. A healthy and convenient option for quick meals. Washed and ready to eat.' WHERE product_id = 37;
UPDATE Products SET product_description = 'A package of pre-cooked, used bacon bits. Perfect for crumbling over salads, potatoes, or eggs. A convenient way to add savory flavor.' WHERE product_id = 38;
UPDATE Products SET product_description = 'A simple, no-fuss pair of pants. Durable cotton blend, straight-leg cut. An affordable and reliable choice for everyday wear.' WHERE product_id = 39;
UPDATE Products SET product_description = 'A premium, gourmet salad kit branded as ''Intelligent''. Features exotic greens, superfood toppings, and a smart, healthy dressing.' WHERE product_id = 40;
UPDATE Products SET product_description = 'A pair of fresh, brand-new shoes, straight out of the box. Stylish design, comfortable fit. Ready to make a statement.' WHERE product_id = 41;
UPDATE Products SET product_description = 'High-performance, insulated gloves. Refined design, ''Frozen'' brand technology for ultimate warmth. Perfect for skiing or winter work.' WHERE product_id = 42;
UPDATE Products SET product_description = 'A brand new laptop, ''Frozen'' brand. Features a cutting-edge cooling system for high-performance computing. Sleek, modern, and powerful.' WHERE product_id = 43;
UPDATE Products SET product_description = 'A pair of lightweight, all-purpose gloves. Good for gardening, light chores, or driving. Provides basic protection and enhanced grip.' WHERE product_id = 44;
UPDATE Products SET product_description = 'A durable, hard-shell plastic hat. Offers protection from the elements. Lightweight and easy to clean. Perfect for outdoor work.' WHERE product_id = 45;
UPDATE Products SET product_description = 'A generic, frozen pizza. ''Fresh'' brand, ready to bake. A quick and easy meal option for a busy night. Topped with cheese and pepperoni.' WHERE product_id = 46;
UPDATE Products SET product_description = 'A beautifully handcrafted shirt. Made by artisans, this shirt features unique stitching and high-quality fabric. A one-of-a-kind garment.' WHERE product_id = 47;
UPDATE Products SET product_description = 'An awesome, super-bouncy rubber ball. Durable and fun, this ball is a classic toy for all ages. Great for fetch or playground games.' WHERE product_id = 48;
UPDATE Products SET product_description = 'A sleek, die-cast metal toy car. High-quality construction with realistic details. A perfect collectible or toy for car enthusiasts.' WHERE product_id = 49;
UPDATE Products SET product_description = 'A bag of ''Practical'' brand potato chips made with 100% cotton oil. A premium, crispy, and delicious snack. Simple, high-quality ingredients.' WHERE product_id = 50;