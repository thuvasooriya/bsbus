## assignment

top-level design: design a serial bus

### specs

- RTL integration
- 2 Master & 3 slaves with 4K (split supported), 4K & 2K
- RTL with async reset & posedge clocks
- implement your design in DE0 board

### tasks

| tasks                  | notes                                                                                                  |
| ---------------------- | ------------------------------------------------------------------------------------------------------ |
| arbiter design         | priority based, split transaction, & io definition (commented)                                         |
| arbiter verification   | reset test, single master request & 2 master requests, & split transaction viable scenario             |
| address decode         | address decoder verification, 3 slaves, address mapping, reset test, and slave select                  |
| top level verification | a) reset test, b) one master request, c) two master requests, and d) split transaction viable scenario |

### notes

your report is evaluated for 20 marks and your demo carries 20 marks.
your report should have functional descriptions, io definition, timing diagrams, rtl & testbench
