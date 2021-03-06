ifeq ($(V),)
  quiet      = quiet_
  Q          = @
  MAKEFLAGS += -s
else
  quiet      =
  Q          =
endif

echo-cmd = $(if $($(quiet)cmd_$(1)), echo "  $($(quiet)cmd_$(1))";)
cmd      = @$(echo-cmd) $(cmd_$(1))

# lla -> ll
cmd_lla_to_ll       = $(CPP) -P $(CPPFLAGS) - < $< > $@
quiet_cmd_lla_to_ll = CPP     $(notdir $@)
%.ll: %.lla
	$(call cmd,lla_to_ll)

# ll -> bc
cmd_ll_to_bc        = $(LLVM_AS) $(LLASFLAGS) -o $@ $<
quiet_cmd_ll_to_bc  = LLVM_AS $(notdir $@)
%.bc: %.ll
	$(call cmd,ll_to_bc)

ifeq ($(COMPILE_THROUGH_AS),)
# bc -> o
cmd_bc_to_o         = $(LLC) $(LLCFLAGS) -filetype=obj -o $@ $<
quiet_cmd_bc_to_o   = LLC     $(notdir $@)
%.o: %.bc
	$(call cmd,bc_to_o)
else
# bc -> s
cmd_ll_to_s         = $(LLC) $(LLCFLAGS) -o $@ $<
quiet_cmd_ll_to_s   = LLC     $(notdir $@)
%.s: %.bc
	$(call cmd,ll_to_s)

# s -> o
cmd_s_to_o          = $(AS) $(ASFLAGS) -o $@ $<
quiet_cmd_s_to_o    = AS      $(notdir $@)
%.o: %.s
	$(call cmd,s_to_o)
endif

# c -> o
cmd_c_to_o          = $(CC) $(CFLAGS) -o $@ $<
quiet_cmd_c_to_o    = CC      $(notdir $@)
%.o: %.c
	$(call cmd,c_to_o)

# hs -> elf
cmd_hs_to_elf       = $(GHC) -o $@ $(GHCFLAGS) -v0 $< $(LLVM_OBJS)
quiet_cmd_hs_to_elf = GHC     $(notdir $@)
%.elf: %.hs $(LLVM_OBJS)
	$(call cmd,hs_to_elf)

# linking target
cmd_ld_done         = $(LD) $(LDFLAGS) -o $@ $< $(LLVM_OBJS)
quiet_cmd_ld_done   = LD      $(notdir $@)
%.elf: %.o $(LLVM_OBJS)
	$(call cmd,ld_done)
