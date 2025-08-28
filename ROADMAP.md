## Plans for '0.5.0' which will be first 'stable' release

### ✅ Completed in Recent Updates
- ✅ **LiveView.js migration** - Updated to modern Phoenix LiveView 1.1+ patterns
- ✅ **Colocated hooks** - Migrated from standalone JS to colocated hooks
- ✅ **Improved error handling** - Better error display and handling
- ✅ **Advanced SQL function support** - Full integration with new Selecto function library

### 🚧 In Progress 
- Make gb rollup an option
- finish various TODOs in the code
- Forms - line forms & column forms
- cleanup liveviews / refactor
- graph view
- make it look nice
- cleanup the event handlers
- error handing on view form

### 📋 Planned Features
- results as XML, JSON, TXT, CSV, PDF, Excel.
- Export results, email results, POST/PUT results
- rename to Selecto.Phoenix
- show generated SQL
- Documentation
- Tests

## Plans for later

- better pagination in detail view, paginate by value, select All
- ability to save view configuration
- generate a token that can be used to generate a specific view, optionally allowing the token holder to access the forms
- Use a column in the results as email address and send that email address all the rows they are in
- Caching
- Dashboard components - save or code a view and drop it into another page
- graphing
- pub sub to trigger updating view
- infinite scroll
- update to work with improved planned selecto interface

This system is inspired by a system I wrote starting in 2004 and currently has all the features listed above except pub-sub and infinite scroll.
