0.0.4 (2009-02-04)
------------------
 - `has_many :through`
 - `has_many :inline`
 - `create` was in 0.0.2 but forgot to mention it :)
 - `all` now emits (id, null) so you can use `:keys => [1,2,3,4]` in your query

0.0.2 (2009-01-24)
------------------
 - `timestamps!` class method now adds instance methods
 - `created_at` and `updated_at` always return an instance of `Time`

0.0.1 (2009-01-21)
------------------
 - Initial Release
