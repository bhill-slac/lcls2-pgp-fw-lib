-------------------------------------------------------------------------------
-- File       : PgpLaneRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- This file is part of 'Camera link gateway'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Camera link gateway', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp3Pkg.all;

entity PgpLaneRx is
   generic (
      TPD_G            : time := 1 ns;
      APP_AXI_CONFIG_G : AxiStreamConfigType;
      PHY_AXI_CONFIG_G : AxiStreamConfigType);
   port (
      -- AXIS Interface (axisClk domain)
      axisClk      : in  sl;
      axisRst      : in  sl;
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType;
      -- PGP Interface (pgpClk domain)
      pgpClk       : in  sl;
      pgpRst       : in  sl;
      rxlinkReady  : in  sl;
      pgpRxMasters : in  AxiStreamMasterArray(3 downto 0);
      pgpRxCtrl    : out AxiStreamCtrlArray(3 downto 0));
end PgpLaneRx;

architecture mapping of PgpLaneRx is

   signal pgpMasters : AxiStreamMasterArray(3 downto 0);
   signal rxMasters  : AxiStreamMasterArray(3 downto 0);
   signal rxSlaves   : AxiStreamSlaveArray(3 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

begin

   BLOWOFF_FILTER : process (pgpRxMasters, rxlinkReady) is
      variable tmp : AxiStreamMasterArray(3 downto 0);
      variable i   : natural;
   begin
      tmp := pgpRxMasters;
      for i in 3 downto 0 loop
         if (rxlinkReady = '0') then
            tmp(i).tValid := '0';
         end if;
      end loop;
      pgpMasters <= tmp;
   end process;

   GEN_VEC :
   for i in 3 downto 0 generate

      PGP_FIFO : entity work.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => false,
            VALID_THOLD_G       => 128,  -- Hold until enough to burst into the interleaving MUX
            VALID_BURST_MODE_G  => true,
            -- FIFO configurations
            BRAM_EN_G           => true,
            GEN_SYNC_FIFO_G     => true,
            FIFO_ADDR_WIDTH_G   => 10,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 256,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => PHY_AXI_CONFIG_G,
            MASTER_AXI_CONFIG_G => APP_AXI_CONFIG_G)
         port map (
            -- Slave Port
            sAxisClk    => pgpClk,
            sAxisRst    => pgpRst,
            sAxisMaster => pgpMasters(i),
            sAxisCtrl   => pgpRxCtrl(i),
            -- Master Port
            mAxisClk    => pgpClk,
            mAxisRst    => pgpRst,
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));

   end generate GEN_VEC;

   U_Mux : entity work.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => 4,
         ILEAVE_EN_G          => true,
         ILEAVE_ON_NOTVALID_G => false,
         ILEAVE_REARB_G       => 128,
         PIPE_STAGES_G        => 1)
      port map (
         -- Clock and reset
         axisClk      => pgpClk,
         axisRst      => pgpRst,
         -- Slaves
         sAxisMasters => rxMasters,
         sAxisSlaves  => rxSlaves,
         -- Master
         mAxisMaster  => rxMaster,
         mAxisSlave   => rxSlave);

   ASYNC_FIFO : entity work.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => APP_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => APP_AXI_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => pgpClk,
         sAxisRst    => pgpRst,
         sAxisMaster => rxMaster,
         sAxisSlave  => rxSlave,
         -- Master Port
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end mapping;