-- Seed: imports the demo catalogue from the frontend into the database.
-- Safe to re-run (upserts on slug). Replace/extend with your real products from /admin later.
insert into public.products (name,slug,description,short_description,category,subcategory,price,features,technologies,is_featured)
values
('Northline Business','northline-business','A trustworthy corporate site with services, team and contact pages.','A trustworthy corporate site with services, team and contact pages.','website','Business Websites',79,'["5 pages", "Contact form UI", "Services grid", "SEO-ready markup"]'::jsonb,'["HTML", "CSS", "JS"]'::jsonb,true),
('Folio Studio','folio-studio','A minimal portfolio that puts your work front and center.','A minimal portfolio that puts your work front and center.','website','Portfolio Websites',49,'["Project gallery", "Case study layout", "About page", "Dark and light modes"]'::jsonb,'["HTML", "CSS", "Animations"]'::jsonb,false),
('Cartwheel Shop','cartwheel-shop','A product storefront with filters, cart and a clean product page.','A product storefront with filters, cart and a clean product page.','website','E-commerce Websites',129,'["Product grid", "Cart drawer", "Filters", "Responsive checkout layout"]'::jsonb,'["HTML", "CSS", "JS"]'::jsonb,false),
('Arcadia Clan','arcadia-clan','A bold community site for gaming teams with roster and news.','A bold community site for gaming teams with roster and news.','website','Gaming Websites',69,'["Team roster", "News feed", "Event calendar", "Discord widget slot"]'::jsonb,'["HTML", "CSS", "JS"]'::jsonb,true),
('Launchpad One','launchpad-one','A single-page launch site built to explain a product fast.','A single-page launch site built to explain a product fast.','website','Landing Pages',35,'["Hero and pricing", "Feature sections", "FAQ accordion", "Lightweight load"]'::jsonb,'["HTML", "CSS"]'::jsonb,false),
('Metrix Dashboard','metrix-dashboard','An analytics dashboard template with charts, tables and cards.','An analytics dashboard template with charts, tables and cards.','website','Dashboard Templates',89,'["Chart layouts", "Data tables", "Sidebar navigation", "Dark theme"]'::jsonb,'["HTML", "CSS", "JS"]'::jsonb,false),
('Warden','warden','Keeps your server tidy with automod, warnings and logs.','Keeps your server tidy with automod, warnings and logs.','discord_bot','Moderation Bots',25,'["Spam filters", "Warn, mute, ban", "Audit logging", "Role-based permissions"]'::jsonb,'["Automod", "Logs", "Warnings"]'::jsonb,true),
('Cadence','cadence','Plays queues from your favorite sources with simple commands.','Plays queues from your favorite sources with simple commands.','discord_bot','Music Bots',19,'["Queue controls", "Playlist saves", "Volume and loop", "Now-playing embed"]'::jsonb,'["Queue", "Playlists", "Volume"]'::jsonb,false),
('Coinly','coinly','Adds a virtual currency, shop and daily rewards to your server.','Adds a virtual currency, shop and daily rewards to your server.','discord_bot','Economy Bots',29,'["Balance and wallet", "Item shop", "Daily rewards", "Leaderboards"]'::jsonb,'["Currency", "Shop", "Daily"]'::jsonb,false),
('Helpdesk','helpdesk','Opens private support tickets with transcripts and staff roles.','Opens private support tickets with transcripts and staff roles.','discord_bot','Ticket Bots',27,'["Ticket panels", "Transcripts", "Staff assignment", "Close and reopen"]'::jsonb,'["Tickets", "Transcripts", "Roles"]'::jsonb,true),
('Toolbox','toolbox','Polls, reminders, welcome messages and reaction roles in one bot.','Polls, reminders, welcome messages and reaction roles in one bot.','discord_bot','Utility Bots',15,'["Polls", "Reminders", "Welcome messages", "Reaction roles"]'::jsonb,'["Polls", "Reminders", "Welcome"]'::jsonb,false),
('Steward','steward','A configurable bot for applications, events and server workflows.','A configurable bot for applications, events and server workflows.','discord_bot','Custom Management Bots',59,'["Application forms", "Event scheduling", "Custom commands", "Setup wizard"]'::jsonb,'["Config", "Events", "Forms"]'::jsonb,false)
on conflict (slug) do update set name=excluded.name, description=excluded.description, price=excluded.price,
  features=excluded.features, technologies=excluded.technologies, subcategory=excluded.subcategory;

insert into public.site_settings (setting_key,setting_value) values
 ('store_name','Mayo Store'),('contact_email','hello@example.com'),
 ('announcement','') ,('social_links','{}'),('support_info','')
on conflict (setting_key) do nothing;

insert into public.payment_methods (code,label,instructions,sort_order) values
 ('bank_transfer','Bank transfer','Send the order total to the account shown on your order confirmation, then submit your reference.',1),
 ('manual_other','Other (manual)','Contact support to arrange payment. Your order stays pending until an admin verifies it.',2)
on conflict (code) do nothing;
