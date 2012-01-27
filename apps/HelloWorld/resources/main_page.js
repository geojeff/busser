// ==========================================================================
// Project:   HelloWorld - mainPage
// Copyright: @2011 My Company, Inc.
// ==========================================================================
/*globals HelloWorld */

// This page describes the main user interface for your application.  
HelloWorld.mainPage = SC.Page.design({

  // The main pane is made visible on screen as soon as your app is loaded.
  // Add childViews to this pane for views to display immediately on page 
  // load.
  mainPane: SC.MainPane.design({
    childViews: 'topView middleView bottomView'.w(),
    
    topView: SC.View.design(SC.Border, {
      layout: { top: 0, left: 0, right: 0, height: 41 },
      borderStyle: SC.BORDER_BOTTOM
    }),
    
    middleView: SC.ScrollView.design({
      hasHorizontalScroller: NO,
      layout: { top: 42, bottom: 42, left: 0, right: 0 },
      backgroundColor: 'white'
    }),
    
    bottomView: SC.View.design(SC.Border, {
      layout: { bottom: 0, left: 0, right: 0, height: 41 },
      borderStyle: SC.BORDER_TOP
    })
  })
});
