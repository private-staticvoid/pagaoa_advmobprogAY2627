# Achilles Troy T. Pagaoa
## INF 231 
## CTADMOBPL: Advanced Mobile Programming

This repository contains a Flutter project developed for the **Advanced Mobile Programming** course.

### Project Overview
The project focuses on advanced Flutter development topics, with an emphasis on **mobile-to-web transactions** and modern cross-platform application development.

## Lab Activity Instance
This repository serves as the workspace for laboratory activities, exercises, and implementations completed throughout the course.

## Laboratory 1 Discussions

### Discussion 1: What is state management in Flutter?
State management in Flutter is the process of managing and controlling data that can change in an app. It keeps the UI updated whenever the state changes, such as changing themes, updating counters, or handling user input. It helps organize data and makes the app easier to maintain as it grows.

### Discussion 2: Discuss the differences between using setState and Provider
setState and Provider are both used for managing state in Flutter, but they are used in different situations.

setState is used for managing local or temporary state inside a single widget. It is simple and works well for small changes, such as updating a counter or changing a value on one page. However, the state cannot easily be shared with other widgets.

Provider is used for managing shared app state that needs to be accessed by multiple widgets. It separates the data logic from the UI and makes it easier to maintain larger applications, such as managing themes, user information, or app settings.

In short, setState is best for simple widget-level changes, while Provider is better for managing data shared across the application like light and dark mode in this application.
