# Decision Tree based Classification
This project is meant to create a program to classify streaming packets against a predefined rule set using decision tree based approach. 

**Key idea**

In this project, we propose a hybrid design based on shared-memory heterogeneous platforms having multi-core CPUs and field programmable gate arrays (FPGA), to support many-field packet classification against large rule set. Our design adopts a decomposition-based algorithm to perform classification, for which all the fields are first independently searched in parallel, then all the partial search results are merged to produce final result. By carefully analyzing the characteristics of search and merge operations, we map search on FPGA and merge on CPU, respectively.


