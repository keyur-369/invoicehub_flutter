-- ========================================================
-- INVOICEHUB SUPABASE SCHEMA
-- Multi-Tenant Shopkeeper Database Setup with RLS
-- ========================================================

-- 1. Keep-Alive Table: number
CREATE TABLE IF NOT EXISTS public.number (
    id BIGINT PRIMARY KEY DEFAULT 1,
    count BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    ping_source TEXT DEFAULT 'website'
);

INSERT INTO public.number (id, count, updated_at, ping_source)
VALUES (1, 1, NOW(), 'initial_setup')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.number ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public select on number table"
    ON public.number FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public insert on number table"
    ON public.number FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Allow public update on number table"
    ON public.number FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.number TO anon, authenticated;

-- 2. Profiles Table (One profile per shopkeeper)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL UNIQUE,
    role TEXT DEFAULT 'shop_owner',
    shop_name TEXT,
    owner_name TEXT,
    gst_number TEXT,
    mobile TEXT,
    email TEXT,
    address TEXT,
    city TEXT,
    logo_url TEXT,
    signature_url TEXT,
    is_profile_completed BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own profile"
    ON public.profiles FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. Product Categories & Brands
CREATE TABLE IF NOT EXISTS public.product_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_name TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "All users can select categories" ON public.product_categories FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert categories" ON public.product_categories FOR INSERT TO authenticated WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.product_brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_name TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.product_brands ENABLE ROW LEVEL SECURITY;
CREATE POLICY "All users can select brands" ON public.product_brands FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert brands" ON public.product_brands FOR INSERT TO authenticated WITH CHECK (true);

-- 4. Master Products (Shop level products)
CREATE TABLE IF NOT EXISTS public.master_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.product_categories(id),
    brand_id UUID REFERENCES public.product_brands(id),
    product_name TEXT NOT NULL,
    unit TEXT DEFAULT 'Pcs',
    default_gst_percentage DECIMAL(5,2) DEFAULT 0.0,
    image_url TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.master_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view products created by them or global" 
    ON public.master_products FOR SELECT TO authenticated 
    USING (created_by IS NULL OR created_by = auth.uid());
CREATE POLICY "Users can insert own master products" 
    ON public.master_products FOR INSERT TO authenticated 
    WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Users can update own master products" 
    ON public.master_products FOR UPDATE TO authenticated 
    USING (auth.uid() = created_by);
CREATE POLICY "Users can delete own master products" 
    ON public.master_products FOR DELETE TO authenticated 
    USING (auth.uid() = created_by);

-- 5. Shop Products (Inventory mapping for shop)
CREATE TABLE IF NOT EXISTS public.shop_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES public.profiles(id) NOT NULL,
    product_id UUID REFERENCES public.master_products(id) NOT NULL,
    custom_rate DECIMAL(10,2) DEFAULT 0.0,
    gst_percentage DECIMAL(5,2) DEFAULT 18.0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.shop_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop owners can manage shop products"
    ON public.shop_products FOR ALL TO authenticated
    USING (shop_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
    WITH CHECK (shop_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- 6. Customers Table
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES public.profiles(id) NOT NULL,
    customer_name TEXT NOT NULL,
    mobile TEXT,
    gst_number TEXT,
    address TEXT,
    city TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop owners can manage own customers"
    ON public.customers FOR ALL TO authenticated
    USING (shop_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
    WITH CHECK (shop_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- 7. Invoices Table
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES public.profiles(id) NOT NULL,
    customer_id UUID REFERENCES public.customers(id),
    invoice_number TEXT NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE,
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.0,
    total_tax DECIMAL(10,2) NOT NULL DEFAULT 0.0,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.0,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0.0,
    status TEXT DEFAULT 'Unpaid',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop owners can manage own invoices"
    ON public.invoices FOR ALL TO authenticated
    USING (shop_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
    WITH CHECK (shop_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- 8. Invoice Items Table
CREATE TABLE IF NOT EXISTS public.invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE CASCADE NOT NULL,
    product_name TEXT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.0,
    gst_percentage DECIMAL(5,2) DEFAULT 0.0,
    tax_amount DECIMAL(10,2) DEFAULT 0.0,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.0
);

ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Shop owners can manage own invoice items"
    ON public.invoice_items FOR ALL TO authenticated
    USING (invoice_id IN (SELECT id FROM public.invoices WHERE shop_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())));

-- ========================================================
-- OPTIONAL DATABASE CLEANUP / RESET SCRIPT
-- Execute the lines below in Supabase SQL Editor if you want to clear old test data
-- ========================================================
-- TRUNCATE TABLE public.invoice_items CASCADE;
-- TRUNCATE TABLE public.invoices CASCADE;
-- TRUNCATE TABLE public.shop_products CASCADE;
-- TRUNCATE TABLE public.master_products CASCADE;
-- TRUNCATE TABLE public.customers CASCADE;
-- TRUNCATE TABLE public.profiles CASCADE;


