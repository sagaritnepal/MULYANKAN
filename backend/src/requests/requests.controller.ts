import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { User } from '@prisma/client';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { RequestsService } from './requests.service';
import { LiveBiddingService } from '../live-bidding/live-bidding.service';
import { CreateRequestDto } from './dto/create-request.dto';
import { AddPhotoDto } from './dto/add-photo.dto';
import { DecideRequestDto } from './dto/decide-request.dto';

@UseGuards(JwtAuthGuard)
@Controller('requests')
export class RequestsController {
  constructor(
    private requests: RequestsService,
    private liveBidding: LiveBiddingService,
  ) {}

  @Post()
  create(@CurrentUser() user: User, @Body() dto: CreateRequestDto) {
    return this.requests.create(user.id, dto);
  }

  @Get('mine')
  mine(@CurrentUser() user: User) {
    return this.requests.listMine(user.id);
  }

  @Get('dashboard')
  dashboard(@CurrentUser() user: User) {
    return this.requests.getDashboard(user.id);
  }

  /**
   * Declared above the `:id` route on purpose — Nest matches in
   * declaration order, so a later `feed` would be swallowed as an id.
   */
  @Get('feed')
  feed(@CurrentUser() user: User) {
    return this.requests.listFeed(user.id);
  }

  @Get(':id')
  get(@Param('id') id: string, @CurrentUser() user: User) {
    return this.requests.findForRole(id, user);
  }

  /** The open bid board; 409s while the vehicle is still blind. */
  @Get(':id/live')
  liveBoard(@Param('id') id: string, @CurrentUser() user: User) {
    return this.liveBidding.board(id, user);
  }

  /**
   * "Inquiring" — interest without a number. Counts toward the live
   * threshold, so three inquiries alone are enough to open bidding.
   */
  @Post(':id/interest')
  interest(@Param('id') id: string, @CurrentUser() user: User) {
    return this.liveBidding.registerInterest(id, user);
  }

  @Get(':id/board')
  board(@Param('id') id: string, @CurrentUser() user: User) {
    return this.requests.board(id, user);
  }

  @Post(':id/edit')
  edit(@Param('id') id: string, @CurrentUser() user: User, @Body() dto: CreateRequestDto) {
    return this.requests.update(id, user, dto);
  }

  @Post(':id/photos')
  addPhoto(@Param('id') id: string, @CurrentUser() user: User, @Body() dto: AddPhotoDto) {
    return this.requests.addPhoto(id, user, dto);
  }

  /** Voids the valuation. See close() for ending the window normally. */
  @Post(':id/cancel')
  cancel(@Param('id') id: string, @CurrentUser() user: User) {
    return this.requests.cancel(id, user);
  }

  @Post(':id/close')
  close(@Param('id') id: string, @CurrentUser() user: User) {
    return this.requests.close(id, user);
  }

  @Post(':id/decide')
  decide(@Param('id') id: string, @CurrentUser() user: User, @Body() dto: DecideRequestDto) {
    return this.requests.decide(id, user, dto);
  }

  @Post(':id/rebroadcast')
  rebroadcast(@Param('id') id: string, @CurrentUser() user: User, @Body() body: { windowSeconds?: number }) {
    return this.requests.rebroadcast(id, user, body?.windowSeconds);
  }

  @Post(':id/start')
  start(@Param('id') id: string, @CurrentUser() user: User, @Body() body: { windowSeconds?: number }) {
    return this.requests.startValuation(id, user, body?.windowSeconds);
  }
}

/** Kept as a top-level /inbox route (not /requests/inbox) to match the API contract. */
@UseGuards(JwtAuthGuard)
@Controller('inbox')
export class InboxController {
  constructor(private requests: RequestsService) {}

  @Get()
  inbox(@CurrentUser() user: User) {
    return this.requests.listInbox(user.id);
  }
}
