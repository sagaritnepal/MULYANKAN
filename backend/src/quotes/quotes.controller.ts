import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { User } from '@prisma/client';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { QuotesService } from './quotes.service';
import { SubmitQuoteDto } from './dto/submit-quote.dto';
import { PassQuoteDto } from './dto/pass-quote.dto';

@UseGuards(JwtAuthGuard)
@Controller('requests/:id')
export class QuotesController {
  constructor(private quotes: QuotesService) {}

  @Post('quote')
  submit(@Param('id') requestId: string, @CurrentUser() user: User, @Body() dto: SubmitQuoteDto) {
    return this.quotes.submit(requestId, user.id, dto);
  }

  @Post('pass')
  pass(@Param('id') requestId: string, @CurrentUser() user: User, @Body() dto: PassQuoteDto) {
    return this.quotes.pass(requestId, user.id, dto);
  }
}
