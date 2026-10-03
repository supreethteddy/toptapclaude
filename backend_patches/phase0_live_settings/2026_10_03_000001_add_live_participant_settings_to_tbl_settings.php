<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Admin-configurable LIVE participant / PK / guest-gifting limits.
     * Defaults match the client's spec: 4 in frame incl. host for Co-host Mode,
     * up to 9 Guest Call participants, 80/20 guest/host gift split, single
     * 5-minute PK round.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('tbl_settings', function (Blueprint $table) {
            $table->unsignedTinyInteger('max_live_cohosts')->default(3);
            $table->unsignedTinyInteger('max_live_guests')->default(9);
            $table->unsignedTinyInteger('guest_gift_host_share_percent')->default(20);
            $table->unsignedSmallInteger('pk_battle_duration_minutes')->default(5);
            $table->unsignedInteger('pk_like_points')->default(1);
            $table->unsignedSmallInteger('pk_invite_expiry_seconds')->default(60);
            $table->boolean('live_guest_requests_enabled')->default(1);
            $table->unsignedTinyInteger('pk_battle_rounds')->default(1);
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('tbl_settings', function (Blueprint $table) {
            $table->dropColumn([
                'max_live_cohosts',
                'max_live_guests',
                'guest_gift_host_share_percent',
                'pk_battle_duration_minutes',
                'pk_like_points',
                'pk_invite_expiry_seconds',
                'live_guest_requests_enabled',
                'pk_battle_rounds',
            ]);
        });
    }
};
